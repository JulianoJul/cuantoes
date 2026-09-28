import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_capture_screen.dart';
import 'ocr_selection_screen.dart';
import '../models/documento_ocr.dart';
import '../services/tasa_repository.dart';
import '../viewmodels/conversor_viewmodel.dart';
import '../services/settings_provider.dart';
import '../services/home_widget_service.dart';
import '../services/widget_background_refresh.dart';
import '../utils/automatic_comma_formatter.dart';
import '../utils/feriados_ve.dart';
import '../models/resultado_tasa.dart';

class ConversorScreen extends StatelessWidget {
  final TasaRepository? repository;
  final Future<void> Function(ResultadoTasa resultado)? onTasaActualizada;

  const ConversorScreen({super.key, this.repository, this.onTasaActualizada});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConversorViewmodel(
        repository: repository,
        onRateAvailable: onTasaActualizada,
      )..cargarTasa(),
      child: const _ConversorBody(),
    );
  }
}

class _ConversorBody extends StatefulWidget {
  const _ConversorBody();

  @override
  State<_ConversorBody> createState() => _ConversorBodyState();
}

class _ConversorBodyState extends State<_ConversorBody>
    with WidgetsBindingObserver {
  bool _lostDataCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        WidgetBackgroundRefresh.actualizarProgramacion().catchError(
          (Object _) {},
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lostDataCheckScheduled) return;
    _lostDataCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _recuperarImagenPerdida(),
    );
  }

  Future<void> _recuperarImagenPerdida() async {
    try {
      final perdida = await ImagePicker().retrieveLostData();
      if (!mounted || perdida.isEmpty) return;
      final archivos = perdida.files;
      final imagen =
          perdida.file ??
          (archivos != null && archivos.isNotEmpty ? archivos.last : null);
      if (imagen == null) {
        _mostrarMensaje('No se pudo recuperar la imagen elegida');
        return;
      }
      await _abrirSeleccionOcr(imagen.path, context.read<ConversorViewmodel>());
    } catch (_) {
      // retrieveLostData is Android-specific; other platforms return no recovery.
    }
  }

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConversorViewmodel>();
    final settings = context.watch<SettingsProvider>();
    final formatter = NumberFormat('#,##0.00', 'es_VE');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Cuantoes'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, vm, settings),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildEstadoBcv(context, vm, formatter),
                  const SizedBox(height: 16),
                  _buildSelectorMoneda(context, vm),
                  const SizedBox(height: 8),
                  _buildSelectorFecha(context, vm, dateFormatter),
                  const SizedBox(height: 12),
                  _buildEntrada(context, vm, settings),
                  const SizedBox(height: 8),
                  Center(child: _buildSwapButton(vm)),
                  const SizedBox(height: 8),
                  _buildResultado(context, vm, formatter),
                  const SizedBox(height: 8),
                  _buildAtajos(vm),
                  const SizedBox(height: 16),
                  _buildEstadoObtencion(context, vm),
                  const SizedBox(height: 8),
                  _buildBotonRecargar(vm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    ConversorViewmodel vm,
    SettingsProvider settings,
  ) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.currency_exchange, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Cuantoes BCV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            subtitle: const Text('Alternar tema visual'),
            value: settings.isDarkMode,
            onChanged: (_) => settings.toggleDarkMode(),
            secondary: Icon(
              settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
          SwitchListTile(
            title: const Text('Coma Automática'),
            subtitle: const Text('Desplaza decimales al escribir (0,00)'),
            value: settings.isAutomaticComma,
            onChanged: (val) {
              settings.toggleAutomaticComma();
              vm.entradaController.clear();
              vm.setEntrada('');
            },
            secondary: const Icon(Icons.edit_note),
          ),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Widget compacto'),
            subtitle: const Text('Moneda mostrada en el widget pequeño'),
            trailing: DropdownButton<String>(
              value: settings.compactWidgetCurrency,
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              ],
              onChanged: (value) {
                if (value == null) return;
                settings.setCompactWidgetCurrency(value);
                unawaited(HomeWidgetService().actualizarMonedaCompacta(value));
              },
            ),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.all(16.0), child: _buildOrigen(vm)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(Icons.currency_exchange, size: 40),
        SizedBox(height: 6),
        Text(
          'Tasa BCV',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSelectorMoneda(BuildContext context, ConversorViewmodel vm) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _chipMoneda(context, vm, 'USD'),
        _chipMoneda(context, vm, 'EUR'),
        _chipMoneda(context, vm, 'USDT'),
      ],
    );
  }

  Widget _chipMoneda(
    BuildContext context,
    ConversorViewmodel vm,
    String moneda,
  ) {
    final selected = vm.moneda == moneda;
    return ChoiceChip(
      label: Text(moneda == 'USDT' ? 'USDT · P2P' : '$moneda · BCV'),
      selected: selected,
      onSelected: (_) => vm.setMoneda(moneda),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSelectorFecha(
    BuildContext context,
    ConversorViewmodel vm,
    DateFormat formatter,
  ) {
    if (vm.moneda == 'USDT') return const SizedBox.shrink();

    final hoy = _hoyVenezuela();

    final mostrarProxima = vm.tasaSiguienteDisponible;

    String label;
    if (vm.fechaSeleccionada != null) {
      final sel = vm.fechaSeleccionada!;
      label = _formatearEtiqueta(sel, formatter);
    } else if (mostrarProxima) {
      label = _formatearEtiqueta(hoy, formatter);
    } else {
      final ef = vm.tasa?.fechaEfectiva ?? hoy;
      label = _formatearEtiqueta(ef, formatter);
    }

    final mostrarVolver = vm.fechaSeleccionada != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mostrarVolver)
              IconButton(
                onPressed: () => vm.volverAHoy(),
                icon: const Icon(Icons.today, size: 20),
                tooltip: 'Volver a hoy',
              ),
            Flexible(
              child: TextButton.icon(
                onPressed: () => _abrirCalendario(context, vm),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (mostrarProxima)
          Text(
            'Tasa siguiente disponible',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Future<void> _abrirCalendario(
    BuildContext context,
    ConversorViewmodel vm,
  ) async {
    final hoy = _hoyVenezuela();
    final firstDate = DateTime(2016, 1, 1);
    final lastDate = vm.fechaMaximaSeleccionable;
    final requestedDate = vm.fechaSeleccionada ?? vm.tasa?.fechaEfectiva ?? hoy;
    final initialDate = _clampDate(requestedDate, firstDate, lastDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es'),
    );
    if (picked != null) {
      await vm.seleccionarFecha(picked);
    }
  }

  Widget _buildEntrada(
    BuildContext context,
    ConversorViewmodel vm,
    SettingsProvider settings,
  ) {
    return IgnorePointer(
      ignoring: vm.entradaBloqueada,
      child: Opacity(
        opacity: vm.entradaBloqueada ? 0.5 : 1,
        child: TextField(
          controller: vm.entradaController,
          onChanged: vm.setEntrada,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            if (settings.isAutomaticComma && !vm.entradaInterpretada)
              AutomaticCommaFormatter(active: true)
            else
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text;
                if (text.isEmpty) return newValue;
                if (RegExp(r'^\d*([,.]\d{0,4})?$').hasMatch(text)) {
                  return newValue;
                }
                return oldValue;
              }),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: vm.cargandoUsdt ? 'Cargando USDT...' : vm.labelOrigen,
            border: const OutlineInputBorder(),
            suffixIcon: vm.entrada.isEmpty
                ? IconButton(
                    tooltip: 'Escanear precio',
                    icon: const Icon(Icons.document_scanner_outlined),
                    onPressed: () => _escanearPrecio(context, vm),
                  )
                : IconButton(
                    tooltip: 'Limpiar monto',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      vm.entradaController.clear();
                      vm.setEntrada('');
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _escanearPrecio(
    BuildContext context,
    ConversorViewmodel vm,
  ) async {
    final origen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, 'camara'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, 'galeria'),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !context.mounted) return;

    String? ruta;
    if (origen == 'camara') {
      ruta = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
    } else {
      try {
        final imagen = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        ruta = imagen?.path;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir la galería')),
          );
        }
        return;
      }
    }
    if (ruta == null || !mounted) return;
    await _abrirSeleccionOcr(ruta, vm);
  }

  Future<void> _abrirSeleccionOcr(String ruta, ConversorViewmodel vm) async {
    final transferencia = await Navigator.push<TransferenciaOcr>(
      context,
      MaterialPageRoute(builder: (_) => OcrSelectionScreen(rutaImagen: ruta)),
    );
    if (!mounted || transferencia == null) return;
    await vm.aplicarMontoEscaneado(
      monto: transferencia.monto,
      moneda: transferencia.moneda,
    );
  }

  Widget _buildSwapButton(ConversorViewmodel vm) {
    return IconButton.filled(
      onPressed: vm.tasaActual > 0 ? vm.toggleDireccion : null,
      tooltip: 'Intercambiar moneda de entrada y resultado',
      icon: const Icon(Icons.swap_vert),
    );
  }

  Widget _buildResultado(
    BuildContext context,
    ConversorViewmodel vm,
    NumberFormat formatter,
  ) {
    if (vm.resultado.isEmpty) {
      return Text(
        vm.labelDestino,
        style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              vm.esMonedaAVes ? 'Bs. ' : '${vm.moneda} ',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            Flexible(
              child: Text(
                formatter.format(
                  double.parse(vm.resultado.replaceAll(',', '.')),
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                final prefix = vm.esMonedaAVes ? 'Bs. ' : '${vm.moneda} ';
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '$prefix${formatter.format(double.parse(vm.resultado.replaceAll(',', '.')))}',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resultado copiado')),
                  );
                }
              },
              visualDensity: VisualDensity.compact,
              tooltip: 'Copiar resultado',
            ),
          ],
        ),
        if (!vm.esMonedaAVes && vm.resultadoPreciso.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Opacity(
              opacity: 0.45,
              child: Text(
                'Cálculo preciso: ${vm.resultadoPreciso.replaceAll('.', ',')} ${vm.moneda}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEstadoBcv(
    BuildContext context,
    ConversorViewmodel vm,
    NumberFormat formatter,
  ) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final tasa = vm.tasa;
    if (tasa == null) {
      if (vm.estado == EstadoTasa.cargando) {
        return const SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: 8),
              Text(
                vm.error.isEmpty
                    ? 'No hay tasas disponibles'
                    : 'No se pudo cargar la tasa',
              ),
              TextButton.icon(
                onPressed: vm.refrescarTasa,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final fechaAplicada = vm.fechaEfectivaAplicada ?? tasa.fechaEfectiva;
    final nombresOrigen = {
      'dolarapi': 'DolarAPI',
      'bcv_today': 'BCV Today',
      'chitty_bcv': 'Chitty BCV',
    };
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tasa oficial BCV',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  nombresOrigen[tasa.origen] ?? tasa.origen,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const Divider(height: 20),
            _rateLine(formatter, vm, 'USD', tasa.usd),
            const SizedBox(height: 8),
            _rateLine(formatter, vm, 'EUR', tasa.eur),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  vm.fechaSeleccionada == null
                      ? 'Fecha valor: ${dateFormatter.format(fechaAplicada)}'
                      : 'Solicitada: ${dateFormatter.format(vm.fechaSeleccionada!)} · aplicada: ${dateFormatter.format(fechaAplicada)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (vm.tasaSiguienteDisponible && vm.fechaTasaSiguiente != null)
                  Text(
                    'Próxima: ${dateFormatter.format(vm.fechaTasaSiguiente!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            if (vm.moneda == 'USDT') ...[
              const Divider(height: 24),
              _buildEstadoUsdt(context, vm, formatter, dateFormatter),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoUsdt(
    BuildContext context,
    ConversorViewmodel vm,
    NumberFormat formatter,
    DateFormat dateFormatter,
  ) {
    final cotizacion = vm.cotizacionUsdt;
    if (cotizacion == null) {
      return Row(
        children: [
          const Expanded(child: Text('Referencia USDT · P2P')),
          if (vm.cargandoUsdt)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              vm.errorUsdt.isEmpty ? 'Sin dato' : 'No disponible',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    }
    final age = DateTime.now().toUtc().difference(cotizacion.obtenidaEnUtc);
    final ageLabel = age.inMinutes < 1
        ? 'ahora'
        : age.inHours < 1
        ? 'hace ${age.inMinutes} min'
        : 'hace ${age.inHours} h';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('USDT · Referencia P2P')),
            Text('1 = Bs. ${formatter.format(cotizacion.valor)}'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${cotizacion.origen} · promedio ${dateFormatter.format(cotizacion.fechaEfectiva)} · consultado $ageLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (vm.cargandoUsdt) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Widget _rateLine(
    NumberFormat formatter,
    ConversorViewmodel vm,
    String moneda,
    double valor,
  ) {
    String? variacionStr;
    Color? variacionColor;
    if (vm.variacion != null && vm.moneda == moneda && moneda != 'USDT') {
      final v = vm.variacion!;
      variacionStr = '${v >= 0 ? "▲" : "▼"} ${v.toStringAsFixed(2)}%';
      variacionColor = v >= 0 ? Colors.green : Colors.red;
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          moneda,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text('1 = Bs. ${formatter.format(valor)}'),
        if (variacionStr != null) ...[
          Text(
            variacionStr,
            style: TextStyle(fontSize: 11, color: variacionColor),
          ),
        ],
      ],
    );
  }

  Widget _buildOrigen(ConversorViewmodel vm) {
    final origen = vm.tasa?.origen ?? '';
    if (origen.isEmpty) return const SizedBox.shrink();

    const nombres = {
      'dolarapi': 'DolarAPI',
      'bcv_today': 'BCV Today',
      'chitty_bcv': 'Chitty BCV',
    };
    final etiqueta = nombres[origen] ?? 'API';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Datos desde $etiqueta',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonRecargar(ConversorViewmodel vm) {
    return TextButton.icon(
      onPressed: vm.moneda == 'USDT' ? vm.refrescarUsdt : vm.refrescarTasa,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text(
        vm.moneda == 'USDT' ? 'Actualizar referencia USDT' : 'Actualizar tasa',
      ),
    );
  }

  Widget _buildAtajos(ConversorViewmodel vm) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final monto in const [1, 10, 50, 100])
          OutlinedButton(
            onPressed: () => vm.setEntrada('$monto'),
            child: Text('$monto ${vm.labelOrigen}'),
          ),
      ],
    );
  }

  Widget _buildEstadoObtencion(BuildContext context, ConversorViewmodel vm) {
    final resultado = vm.resultadoTasa;
    if (vm.error.isEmpty && resultado == null) return const SizedBox.shrink();
    final validacion = resultado?.ultimaValidacionExitosaUtc;
    final edad = validacion == null
        ? null
        : DateTime.now().toUtc().difference(validacion).inMinutes;
    final falloActualizacion = resultado?.errorActualizacion != null;
    final mensaje = vm.error.isNotEmpty || falloActualizacion
        ? resultado?.frescura == EstadoFrescuraTasa.antigua
              ? 'No se pudo actualizar · se conserva una tasa antigua; verifica su fecha efectiva.'
              : 'No se pudo actualizar · se conserva la última tasa disponible.'
        : resultado?.frescura == EstadoFrescuraTasa.antigua
        ? 'La fecha efectiva disponible es antigua; revisa antes de usarla.'
        : resultado?.vieneDeCache == true
        ? edad == null || edad < 0
              ? 'Tasa guardada · última validación desconocida'
              : edad < 1
              ? 'Tasa guardada · validada hace menos de 1 min'
              : 'Tasa guardada · validada hace $edad min'
        : '';
    if (mensaje.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: TextStyle(
          color:
              vm.error.isNotEmpty ||
                  falloActualizacion ||
                  resultado?.frescura == EstadoFrescuraTasa.antigua
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatearEtiqueta(DateTime fecha, DateFormat formatter) {
    final dia = _soloFecha(fecha);
    final hoy = _hoyVenezuela();
    final fechaStr = formatter.format(dia);

    if (_esMismaFecha(dia, hoy)) return 'Hoy - $fechaStr';

    final manana = hoy.add(const Duration(days: 1));
    if (_esMismaFecha(dia, manana)) return 'Mañana - $fechaStr';

    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final nombre = dias[dia.weekday - 1];
    return '$nombre - $fechaStr';
  }

  DateTime _hoyVenezuela() {
    final ahora = ahoraVenezuela();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  DateTime _clampDate(DateTime fecha, DateTime firstDate, DateTime lastDate) {
    final dia = _soloFecha(fecha);
    if (dia.isBefore(firstDate)) return firstDate;
    if (dia.isAfter(lastDate)) return lastDate;
    return dia;
  }

  bool _esMismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
