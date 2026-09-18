import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_capture_screen.dart';
import '../viewmodels/conversor_viewmodel.dart';
import '../services/settings_provider.dart';
import '../services/ocr_service.dart';
import '../utils/automatic_comma_formatter.dart';
import '../utils/feriados_ve.dart';
import '../utils/numeros_ocr.dart';

class ConversorScreen extends StatelessWidget {
  const ConversorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConversorViewmodel()..cargarTasa(),
      child: const _ConversorBody(),
    );
  }
}

class _ConversorBody extends StatelessWidget {
  const _ConversorBody();

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, vm, settings),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildSelectorMoneda(context, vm),
              const SizedBox(height: 8),
              _buildSelectorFecha(context, vm, dateFormatter),
              const SizedBox(height: 20),
              _buildEntrada(context, vm, settings),
              const SizedBox(height: 20),
              _buildSwapButton(vm),
              const SizedBox(height: 20),
              _buildResultado(vm, formatter),
              const SizedBox(height: 16),
              _buildEstadoBcv(context, vm, formatter),
              const Spacer(),
              _buildBotonRecargar(vm),
              const SizedBox(height: 12),
            ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chipMoneda(context, vm, 'USD'),
        const SizedBox(width: 8),
        _chipMoneda(context, vm, 'EUR'),
        const SizedBox(width: 8),
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
      label: Text(moneda),
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

    final mostrarVolver =
        vm.fechaSeleccionada != null &&
        _soloFecha(vm.fechaSeleccionada!).isBefore(hoy);

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
            TextButton.icon(
              onPressed: () => _abrirCalendario(context, vm),
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(label),
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
            AutomaticCommaFormatter(active: settings.isAutomaticComma),
            if (!settings.isAutomaticComma)
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text;
                if (text.isEmpty) return newValue;
                if (RegExp(r'^\d*([,.]\d{0,2})?$').hasMatch(text)) {
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
            suffixIcon: IconButton(
              tooltip: 'Escanear precio',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => _escanearPrecio(context, vm),
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
    if (ruta == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String texto;
    try {
      texto = await OcrService().reconocerTexto(ruta);
    } catch (_) {
      texto = '';
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return;

    if (texto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se detectó texto en la imagen')),
      );
      return;
    }

    final seleccionado = await showDialog<String>(
      context: context,
      builder: (_) => _OcrDialog(texto: texto, numeros: extraerNumeros(texto)),
    );
    if (seleccionado == null) return;

    vm.entradaController.text = seleccionado;
    vm.setEntrada(seleccionado);
  }

  Widget _buildSwapButton(ConversorViewmodel vm) {
    return IconButton.filled(
      onPressed: vm.tasa != null ? vm.toggleDireccion : null,
      icon: const Icon(Icons.swap_vert),
    );
  }

  Widget _buildResultado(ConversorViewmodel vm, NumberFormat formatter) {
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
              onPressed: () {
                final prefix = vm.esMonedaAVes ? 'Bs. ' : '${vm.moneda} ';
                Clipboard.setData(
                  ClipboardData(
                    text:
                        '$prefix${formatter.format(double.parse(vm.resultado.replaceAll(',', '.')))}',
                  ),
                );
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

    switch (vm.estado) {
      case EstadoTasa.cargando:
        return const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadoTasa.error:
        return SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(height: 4),
              Text(
                vm.error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case EstadoTasa.listo:
        final t = vm.tasa!;
        final fechaAplicada = vm.fechaEfectivaAplicada ?? t.fechaEfectiva;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _rateLine(formatter, vm, 'USD', t.usd),
              const SizedBox(height: 4),
              _rateLine(formatter, vm, 'EUR', t.eur),
              if (t.usdt > 0) ...[
                const SizedBox(height: 4),
                _rateLine(formatter, vm, 'USDT', t.usdt),
              ],
              const SizedBox(height: 6),
              Text(
                vm.fechaSeleccionada != null
                    ? 'Tasa aplicada: ${dateFormatter.format(fechaAplicada)}'
                    : dateFormatter.format(fechaAplicada),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
    }
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          moneda,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text('1 = Bs. ${formatter.format(valor)}'),
        if (variacionStr != null) ...[
          const SizedBox(width: 8),
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

    final esScraping = origen.startsWith('scraping');
    final icono = esScraping ? Icons.language : Icons.cloud;
    final etiqueta = esScraping ? 'BCV directo' : 'API';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 14, color: Colors.grey),
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
      onPressed: () => vm.refrescarTasa(),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Actualizar tasa'),
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

class _OcrDialog extends StatefulWidget {
  final String texto;
  final List<NumeroDetectado> numeros;

  const _OcrDialog({required this.texto, required this.numeros});

  @override
  State<_OcrDialog> createState() => _OcrDialogState();
}

class _OcrDialogState extends State<_OcrDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.texto);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _usarSeleccion() {
    final seleccion = _controller.selection;
    final texto = seleccion.isValid && !seleccion.isCollapsed
        ? _controller.text.substring(seleccion.start, seleccion.end)
        : _controller.text;
    final valor = parsearNumero(texto);
    if (valor == null) {
      setState(() => _error = 'Selecciona un número válido del texto');
      return;
    }
    Navigator.pop(context, _formatoEntrada(valor));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Texto detectado'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                readOnly: true,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Mantén presionado para seleccionar el número',
                ),
              ),
              if (widget.numeros.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Números detectados',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final numero in widget.numeros.take(12))
                      ActionChip(
                        label: Text(numero.texto),
                        onPressed: () => Navigator.pop(
                          context,
                          _formatoEntrada(numero.valor),
                        ),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _usarSeleccion,
          child: const Text('Usar selección'),
        ),
      ],
    );
  }
}

String _formatoEntrada(double valor) {
  final texto = valor.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  return texto.replaceAll('.', ',');
}
