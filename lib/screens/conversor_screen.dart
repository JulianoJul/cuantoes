import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/documento_ocr.dart';
import '../models/resultado_tasa.dart';
import '../services/settings_provider.dart';
import '../services/tasa_repository.dart';
import '../services/widget_background_refresh.dart';
import '../utils/automatic_comma_formatter.dart';
import '../utils/currency_labels.dart';
import '../viewmodels/conversor_viewmodel.dart';
import 'camera_capture_screen.dart';
import 'ocr_selection_screen.dart';
import 'rate_date_picker.dart';
import 'rates_sheet.dart';
import 'settings_screen.dart';

const _widgetActionChannel = MethodChannel('ve.cuantoes/widget_action');

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
  final FocusNode _montoFocusNode = FocusNode();
  bool _lostDataCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetActionChannel.setMethodCallHandler(_handleWidgetAction);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeWidgetAction());
  }

  Future<dynamic> _handleWidgetAction(MethodCall call) async {
    if (call.method == 'focusAmount') _focusAmount();
  }

  Future<void> _consumeWidgetAction() async {
    try {
      final shouldFocus =
          await _widgetActionChannel.invokeMethod<bool>('consumeFocusAmount') ??
          false;
      if (shouldFocus) _focusAmount();
    } on MissingPluginException {
      // Los tests y plataformas no Android no registran este canal.
    } on PlatformException {
      // Abrir desde el widget es una mejora; no debe bloquear el conversor.
    }
  }

  void _focusAmount() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _montoFocusNode.requestFocus();
    });
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
    _widgetActionChannel.setMethodCallHandler(null);
    _montoFocusNode.dispose();
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
      await _abrirSeleccionOcr(imagen.path);
    } catch (_) {
      // En plataformas sin recuperación de ImagePicker no hay selección pendiente.
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        key: const Key('dismiss-keyboard-area'),
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const verticalPadding = 32.0;
              final minContentHeight = constraints.maxHeight > verticalPadding
                  ? constraints.maxHeight - verticalPadding
                  : 0.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        key: const Key('home-content'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildConversionPanel(
                            context,
                            vm,
                            settings,
                            compact: constraints.maxHeight < 520,
                          ),
                          const SizedBox(height: 12),
                          _buildSecondaryActions(vm, settings),
                          const SizedBox(height: 12),
                          _buildScanButton(),
                          const SizedBox(height: 12),
                          _buildRateSummary(context, vm),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversionPanel(
    BuildContext context,
    ConversorViewmodel vm,
    SettingsProvider settings, {
    required bool compact,
  }) {
    final tema = Theme.of(context);
    final formatoMonto = NumberFormat('#,##0.00', 'es_VE');
    final padding = compact ? 14.0 : 20.0;

    return Card(
      key: const Key('conversion-panel'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: tema.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: compact ? 8 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPairSelector(context, vm),
            const SizedBox(height: 16),
            TextField(
              focusNode: _montoFocusNode,
              controller: vm.entradaController,
              onChanged: vm.setEntrada,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                if (settings.isAutomaticComma && !vm.entradaInterpretada)
                  AutomaticCommaFormatter(active: true)
                else
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text;
                    if (text.isEmpty ||
                        RegExp(r'^\d*([,.]\d{0,2})?$').hasMatch(text)) {
                      return newValue;
                    }
                    return oldValue;
                  }),
              ],
              style: TextStyle(
                fontSize: compact ? 32 : 36,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
              decoration: InputDecoration(
                labelText: 'Monto en ${vm.labelOrigen}',
                hintText: '0,00',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: compact,
                suffixIcon: vm.entrada.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar monto',
                        onPressed: () {
                          vm.entradaController.clear();
                          vm.setEntrada('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Resultado en ${vm.labelDestino}',
                        style: tema.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      _buildResultadoValor(context, vm, formatoMonto, compact),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar resultado',
                  onPressed: vm.resultado.isEmpty
                      ? null
                      : () => _copiarResultado(context, vm, formatoMonto),
                  icon: const Icon(Icons.copy_all_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairSelector(BuildContext context, ConversorViewmodel vm) {
    final selector = Expanded(
      child: DropdownButtonHideUnderline(
        key: const Key('currency-pair-selector'),
        child: DropdownButton<String>(
          value: vm.moneda,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          items: monedasConversor
              .map(
                (moneda) => DropdownMenuItem(
                  value: moneda,
                  child: Text(etiquetaSelectorMoneda(moneda)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) vm.setMoneda(value);
          },
        ),
      ),
    );
    final ves = Container(
      key: const Key('ves-pair-label'),
      constraints: const BoxConstraints(minWidth: 72),
      alignment: vm.esMonedaAVes ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        etiquetaMoneda('VES'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    final monedas = Row(
      children: vm.esMonedaAVes
          ? [
              selector,
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 20),
              const SizedBox(width: 10),
              ves,
            ]
          : [
              ves,
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 20),
              const SizedBox(width: 10),
              selector,
            ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        monedas,
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            key: const Key('swap-direction-button'),
            onPressed: vm.tasaActual > 0 ? vm.toggleDireccion : null,
            icon: const Icon(Icons.swap_horiz),
            label: Text('Intercambiar VES y ${vm.moneda}'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultadoValor(
    BuildContext context,
    ConversorViewmodel vm,
    NumberFormat formato,
    bool compact,
  ) {
    final valor = double.tryParse(vm.resultado.replaceAll(',', '.'));
    final disponible = vm.tasaActual > 0;
    final texto = valor != null
        ? formato.format(valor)
        : disponible
        ? '—'
        : 'Sin tasa disponible';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Semantics(
        label: '${vm.labelDestino}: $texto',
        child: Text(
          texto,
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 27 : 32,
            fontWeight: FontWeight.w700,
            color: valor == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() => SizedBox(
    height: 52,
    child: FilledButton.tonalIcon(
      onPressed: _escanearPrecio,
      icon: const Icon(Icons.document_scanner_outlined),
      label: const Text('Escanear texto o monto'),
    ),
  );

  Widget _buildSecondaryActions(
    ConversorViewmodel vm,
    SettingsProvider settings,
  ) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 52,
          child: FilledButton.tonalIcon(
            onPressed: vm.moneda == 'USDT'
                ? null
                : () => mostrarCalendarioTasa(context, vm),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Calendario'),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: 52,
          child: FilledButton.tonalIcon(
            onPressed: () => _abrirAjustes(settings),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Ajustes'),
          ),
        ),
      ),
    ],
  );

  Widget _buildRateSummary(BuildContext context, ConversorViewmodel vm) {
    final formatoTasa = NumberFormat('#,##0.00', 'es_VE');
    final formatoFecha = DateFormat('dd/MM/yyyy', 'es_VE');
    final tasaDisponible = vm.moneda == 'USDT'
        ? vm.cotizacionUsdt != null
        : vm.tasa != null;
    final errorActual =
        vm.resultadoTasa?.errorActualizacion != null || vm.error.isNotEmpty;
    final antigua = vm.resultadoTasa?.frescura == EstadoFrescuraTasa.antigua;

    String titulo;
    String detalle;
    if (vm.moneda == 'USDT') {
      final cotizacion = vm.cotizacionUsdt;
      titulo = cotizacion == null
          ? vm.cargandoUsdt
                ? 'Cargando referencia P2P…'
                : 'Sin referencia USDT disponible'
          : '1 USDT = Bs. ${formatoTasa.format(cotizacion.valor)}';
      detalle = cotizacion == null
          ? 'Referencia P2P independiente de las tasas BCV'
          : 'P2P · ${cotizacion.origen} · promedio ${formatoFecha.format(cotizacion.fechaEfectiva)}';
    } else {
      final tasa = vm.tasa;
      final valor = tasa?.de(vm.moneda);
      titulo = valor == null
          ? vm.estado == EstadoTasa.cargando
                ? 'Cargando tasas BCV…'
                : 'Sin tasa disponible'
          : '1 ${vm.moneda} = Bs. ${formatoTasa.format(valor)}';
      detalle = tasa == null
          ? vm.error.isEmpty
                ? 'Toca para ver las tasas y fechas'
                : 'No se pudo cargar · toca para reintentar'
          : _contextoFecha(vm, formatoFecha);
    }

    final colorEstado = errorActual || antigua
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final resumen = Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirTasas(vm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                vm.moneda == 'USDT'
                    ? Icons.currency_exchange
                    : Icons.account_balance_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: errorActual || antigua ? colorEstado : null,
                      ),
                    ),
                    if (errorActual || antigua)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          errorActual
                              ? 'No se pudo actualizar · se conserva la tasa'
                              : 'Fecha efectiva antigua · verifica el valor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: colorEstado),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                tasaDisponible ? Icons.chevron_right : Icons.refresh,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );

    if (tasaDisponible || vm.estado == EstadoTasa.cargando || vm.cargandoUsdt) {
      return resumen;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        resumen,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: vm.moneda == 'USDT'
                ? vm.refrescarUsdt
                : vm.refrescarTasa,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }

  String _contextoFecha(ConversorViewmodel vm, DateFormat formatoFecha) {
    final aplicada = vm.fechaEfectivaAplicada ?? vm.tasa?.fechaEfectiva;
    final solicitada = vm.fechaSeleccionada;
    if (solicitada != null) {
      final esProxima =
          vm.fechaTasaSiguiente != null &&
          _mismaFecha(solicitada, vm.fechaTasaSiguiente!);
      if (esProxima) return 'Próxima · ${formatoFecha.format(solicitada)}';
      return aplicada == null
          ? 'Histórico · solicitada ${formatoFecha.format(solicitada)}'
          : 'Histórico · ${formatoFecha.format(solicitada)} → ${formatoFecha.format(aplicada)}';
    }

    final fecha = aplicada == null
        ? 'Fecha efectiva pendiente'
        : 'Fecha valor ${formatoFecha.format(aplicada)}';
    final estadoCache = vm.resultadoTasa?.vieneDeCache == true
        ? ' · tasa guardada'
        : '';
    return '$fecha$estadoCache';
  }

  Future<void> _abrirTasas(ConversorViewmodel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => RatesSheet(viewModel: vm),
    );
  }

  Future<void> _abrirAjustes(SettingsProvider settings) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(settings: settings),
      ),
    );
  }

  Future<void> _copiarResultado(
    BuildContext context,
    ConversorViewmodel vm,
    NumberFormat formato,
  ) async {
    final valor = double.tryParse(vm.resultado.replaceAll(',', '.'));
    if (valor == null) return;
    final texto = formato.format(valor);
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resultado copiado')));
  }

  Future<void> _escanearPrecio() async {
    final restaurarFoco = _montoFocusNode.hasFocus;
    final ruta = await _elegirImagen();
    if (ruta == null || !mounted) {
      if (restaurarFoco) _montoFocusNode.requestFocus();
      return;
    }
    await _abrirSeleccionOcr(ruta, restaurarFoco: restaurarFoco);
  }

  Future<String?> _elegirImagen() async {
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
    if (origen == null || !mounted) return null;

    if (origen == 'camara') {
      return Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
    }

    try {
      final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      return imagen?.path;
    } catch (_) {
      _mostrarMensaje('No se pudo abrir la galería');
      return null;
    }
  }

  Future<void> _abrirSeleccionOcr(
    String ruta, {
    bool restaurarFoco = false,
  }) async {
    final vm = context.read<ConversorViewmodel>();
    FocusManager.instance.primaryFocus?.unfocus();
    final transferencia = await Navigator.push<TransferenciaOcr>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrSelectionScreen(
          rutaImagen: ruta,
          onElegirOtraImagen: _elegirImagen,
          monedaConversor: vm.moneda,
        ),
      ),
    );
    if (!mounted) return;
    if (transferencia != null) {
      await vm.aplicarMontoEscaneado(
        monto: transferencia.monto,
        moneda: transferencia.moneda,
      );
    }
    if (restaurarFoco && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _montoFocusNode.requestFocus();
      });
    }
  }

  bool _mismaFecha(DateTime primera, DateTime segunda) =>
      primera.year == segunda.year &&
      primera.month == segunda.month &&
      primera.day == segunda.day;
}
