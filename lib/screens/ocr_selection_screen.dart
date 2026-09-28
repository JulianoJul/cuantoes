import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/documento_ocr.dart';
import '../services/ocr_service.dart';
import '../utils/numeros_ocr.dart';
import '../utils/ocr_coordinate_mapper.dart';

class OcrSelectionScreen extends StatefulWidget {
  final String rutaImagen;
  final OcrService servicio;
  final Future<String?> Function()? onElegirOtraImagen;
  final String monedaConversor;

  const OcrSelectionScreen({
    super.key,
    required this.rutaImagen,
    this.servicio = const OcrService(),
    this.onElegirOtraImagen,
    this.monedaConversor = 'USD',
  });

  @override
  State<OcrSelectionScreen> createState() => _OcrSelectionScreenState();
}

class _OcrSelectionScreenState extends State<OcrSelectionScreen> {
  late String _rutaImagenActual;
  DocumentoOcr? _documento;
  Object? _error;
  final Set<String> _seleccion = {};
  int? _anclaArrastre;
  bool _procesando = true;

  @override
  void initState() {
    super.initState();
    _rutaImagenActual = widget.rutaImagen;
    _reconocer();
  }

  Future<void> _reconocer() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final documento = await widget.servicio.reconocerDocumento(
        _rutaImagenActual,
      );
      if (!mounted) return;
      setState(() {
        _documento = documento;
        _seleccion.clear();
        _procesando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _procesando = false;
      });
    }
  }

  List<RegionOcr> get _regionesSeleccionadas {
    final documento = _documento;
    if (documento == null) return const [];
    return documento.regiones
        .where((region) => _seleccion.contains(region.id))
        .toList()
      ..sort((a, b) => a.indice.compareTo(b.indice));
  }

  String get _textoSeleccionado {
    final regiones = _regionesSeleccionadas;
    final resultado = StringBuffer();
    RegionOcr? anterior;
    for (final region in regiones) {
      if (anterior != null) {
        resultado.write(
          anterior.bloque == region.bloque && anterior.linea == region.linea
              ? ' '
              : '\n',
        );
      }
      resultado.write(region.texto);
      anterior = region;
    }
    return resultado.toString();
  }

  List<List<RegionOcr>> get _lineas {
    final documento = _documento;
    if (documento == null) return const [];
    final lineas = <String, List<RegionOcr>>{};
    for (final region in documento.regiones) {
      lineas
          .putIfAbsent('${region.bloque}:${region.linea}', () => [])
          .add(region);
    }
    return lineas.values.toList();
  }

  void _seleccionarRegion(RegionOcr? region) {
    setState(() {
      _anclaArrastre = null;
      if (region == null) {
        _seleccion.clear();
      } else if (_seleccion.length == 1 && _seleccion.contains(region.id)) {
        _seleccion.clear();
      } else {
        _seleccion
          ..clear()
          ..add(region.id);
      }
    });
  }

  RegionOcr? _buscarRegion(PuntoOcr punto) {
    final documento = _documento;
    if (documento == null) return null;
    final coincidencias = documento.regiones.where((region) {
      if (region.poligono.length >= 3) {
        return _dentroPoligono(punto, region.poligono);
      }
      return punto.x >= region.izquierda &&
          punto.x <= region.izquierda + region.ancho &&
          punto.y >= region.arriba &&
          punto.y <= region.arriba + region.alto;
    }).toList()..sort((a, b) => (a.ancho * a.alto).compareTo(b.ancho * b.alto));
    if (coincidencias.isNotEmpty) return coincidencias.first;

    // Tolerancia de toque de 24 dp convertida a coordenadas de imagen.
    final mapper = _mapperActual;
    if (mapper == null || mapper.escala == 0) return null;
    final tolerancia = 24 / mapper.escala;
    RegionOcr? masCercana;
    var distanciaMinima = double.infinity;
    for (final region in documento.regiones) {
      final centroX = region.izquierda + region.ancho / 2;
      final centroY = region.arriba + region.alto / 2;
      final distancia = _distancia(punto.x, punto.y, centroX, centroY);
      if (distancia < distanciaMinima && distancia <= tolerancia * tolerancia) {
        distanciaMinima = distancia;
        masCercana = region;
      }
    }
    return masCercana;
  }

  OcrCoordinateMapper? _mapperActual;

  void _iniciarSeleccion(
    PointerEventDetails details,
    OcrCoordinateMapper mapper,
  ) {
    final punto = _aImagen(details.localPosition, mapper);
    final region = _buscarRegion(punto);
    if (region == null) return;
    setState(() {
      _anclaArrastre = region.indice;
      _seleccion
        ..clear()
        ..add(region.id);
    });
  }

  void _extenderSeleccion(
    PointerEventDetails details,
    OcrCoordinateMapper mapper,
  ) {
    final ancla = _anclaArrastre;
    if (ancla == null) return;
    final region = _buscarRegion(_aImagen(details.localPosition, mapper));
    if (region == null) return;
    final documento = _documento;
    if (documento == null) return;
    final desde = ancla < region.indice ? ancla : region.indice;
    final hasta = ancla > region.indice ? ancla : region.indice;
    setState(() {
      _seleccion
        ..clear()
        ..addAll(
          documento.regiones
              .where(
                (element) => element.indice >= desde && element.indice <= hasta,
              )
              .map((element) => element.id),
        );
    });
  }

  PuntoOcr _aImagen(Offset punto, OcrCoordinateMapper mapper) =>
      mapper.aCoordenadasImagen(PuntoVistaOcr(punto.dx, punto.dy));

  double _distancia(double x1, double y1, double x2, double y2) =>
      ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

  bool _dentroPoligono(PuntoOcr punto, List<PuntoOcr> poligono) {
    var dentro = false;
    for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
      final a = poligono[i];
      final b = poligono[j];
      final cruza =
          ((a.y > punto.y) != (b.y > punto.y)) &&
          (punto.x < (b.x - a.x) * (punto.y - a.y) / (b.y - a.y) + a.x);
      if (cruza) dentro = !dentro;
    }
    return dentro;
  }

  Future<void> _copiar() async {
    final texto = _textoSeleccionado;
    if (texto.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Texto copiado')));
    }
  }

  Future<void> _usarMonto() async {
    final candidatos = extraerNumeros(_textoSeleccionado);
    if (candidatos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona texto que incluya un monto')),
      );
      return;
    }

    final candidato = candidatos.length == 1
        ? candidatos.single
        : await showModalBottomSheet<NumeroDetectado>(
            context: context,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text('Elige el monto que quieres usar'),
                  ),
                  for (final numero in candidatos)
                    ListTile(
                      title: Text(numero.texto),
                      subtitle: numero.separadorAmbiguo
                          ? const Text('Revisar separador de miles/decimales')
                          : null,
                      onTap: () => Navigator.pop(context, numero),
                    ),
                ],
              ),
            ),
          );
    if (candidato == null || !mounted) return;

    final resultado = await showDialog<TransferenciaOcr>(
        context: context,
        builder: (context) => _EditarMontoOcrDialog(
          candidato: candidato,
          monedaInicial: _monedaSugerida(candidato),
          monedaConversor: widget.monedaConversor,
        ),
    );
    if (resultado != null && mounted) Navigator.pop(context, resultado);
  }

  String _monedaSugerida(NumeroDetectado candidato) {
    if (candidato.monedaSugerida != null) return candidato.monedaSugerida!;
    var inicioRegion = 0;
    RegionOcr? anterior;
    for (final region in _regionesSeleccionadas) {
      if (anterior != null) inicioRegion++;
      final finRegion = inicioRegion + region.texto.length;
      if (candidato.inicio >= inicioRegion && candidato.fin <= finRegion) {
        return region.monedaSugerida ?? 'USD';
      }
      inicioRegion = finRegion;
      anterior = region;
    }
    return 'USD';
  }

  Future<void> _elegirOtraImagen() async {
    final elegir = widget.onElegirOtraImagen;
    if (elegir == null || _procesando) return;
    final nuevaRuta = await elegir();
    if (!mounted || nuevaRuta == null) return;
    setState(() {
      _rutaImagenActual = nuevaRuta;
      _documento = null;
      _error = null;
      _seleccion.clear();
      _anclaArrastre = null;
    });
    await _reconocer();
  }

  void _seleccionarLinea(List<RegionOcr> linea) {
    setState(() {
      final ids = linea.map((region) => region.id).toSet();
      if (_seleccion.containsAll(ids)) {
        _seleccion.removeAll(ids);
      } else {
        _seleccion.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final documento = _documento;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar texto'),
        actions: [
          IconButton(
            tooltip: 'Seleccionar todo',
            onPressed: documento == null
                ? null
                : () => setState(
                    () => _seleccion
                      ..clear()
                      ..addAll(documento.regiones.map((region) => region.id)),
                  ),
            icon: const Icon(Icons.select_all),
          ),
          IconButton(
            tooltip: 'Limpiar selección',
            onPressed: _seleccion.isEmpty
                ? null
                : () => setState(_seleccion.clear),
            icon: const Icon(Icons.deselect),
          ),
          IconButton(
            tooltip: 'Repetir reconocimiento',
            onPressed: _procesando ? null : _reconocer,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Elegir otra imagen',
            onPressed: _procesando || widget.onElegirOtraImagen == null
                ? null
                : _elegirOtraImagen,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: _procesando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reconociendo texto en el dispositivo…'),
                ],
              ),
            )
          : _error != null
          ? _buildError()
          : documento == null
          ? const Center(child: Text('No se pudo abrir la imagen'))
          : Column(
              children: [
                Expanded(child: _buildImage(documento)),
                if (documento.textoCompleto.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'No se detectó texto en esta imagen.',
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onElegirOtraImagen == null
                              ? null
                              : _elegirOtraImagen,
                          child: const Text('Elegir otra'),
                        ),
                      ],
                    ),
                  ),
                _buildAccesibilidad(documento),
                _buildSelectionPanel(),
              ],
            ),
    );
  }

  Widget _buildImage(DocumentoOcr documento) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapper = OcrCoordinateMapper(
          anchoImagen: documento.anchoImagen.toDouble(),
          altoImagen: documento.altoImagen.toDouble(),
          anchoVista: constraints.maxWidth,
          altoVista: constraints.maxHeight,
        );
        _mapperActual = mapper;
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          panEnabled: true,
          scaleEnabled: true,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _seleccionarRegion(
                _buscarRegion(_aImagen(details.localPosition, mapper)),
              ),
              onLongPressStart: (details) => _iniciarSeleccion(
                PointerEventDetails(details.localPosition),
                mapper,
              ),
              onLongPressMoveUpdate: (details) => _extenderSeleccion(
                PointerEventDetails(details.localPosition),
                mapper,
              ),
              onLongPressEnd: (_) => setState(() => _anclaArrastre = null),
              child: Stack(
                fit: StackFit.expand,
                children: [
                   Image.file(File(_rutaImagenActual), fit: BoxFit.contain),
                   CustomPaint(
                     painter: _OverlayOcrPainter(
                       documento: documento,
                       mapper: mapper,
                       seleccion: Set<String>.unmodifiable(_seleccion),
                       color: Theme.of(context).colorScheme.primary,
                     ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccesibilidad(DocumentoOcr documento) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Texto accesible'),
      children: [
        if (_lineas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(documento.textoCompleto),
          )
        else
          SizedBox(
            height: 130,
            child: ListView(
              children: [
                for (final linea in _lineas)
                  InkWell(
                    onTap: () => _seleccionarLinea(linea),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Semantics(
                        button: true,
                        label:
                            'Seleccionar línea: ${linea.map((r) => r.texto).join(' ')}',
                        child: SelectableText(
                          linea.map((r) => r.texto).join(' '),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionPanel() {
    final texto = _textoSeleccionado;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                texto.isEmpty
                    ? 'Toca una palabra o mantén y arrastra para seleccionar'
                    : texto,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: texto.isEmpty ? null : _copiar,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                  FilledButton.icon(
                    onPressed: texto.isEmpty ? null : _usarMonto,
                    icon: const Icon(Icons.currency_exchange),
                    label: const Text('Usar monto'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    final error = _error;
    final mensaje = error is OcrException
        ? error.mensajeUsuario
        : 'No se pudo procesar esta imagen.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _reconocer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                FilledButton.icon(
                  onPressed: widget.onElegirOtraImagen == null
                      ? null
                      : _elegirOtraImagen,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir otra imagen'),
                ),
              ],
            ),
            if (error is OcrException) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Detalles técnicos'),
                children: [
                  SelectableText(
                    '${error.etapa.name}: ${error.detalleTecnico}',
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayOcrPainter extends CustomPainter {
  final DocumentoOcr documento;
  final OcrCoordinateMapper mapper;
  final Set<String> seleccion;
  final Color color;

  const _OverlayOcrPainter({
    required this.documento,
    required this.mapper,
    required this.seleccion,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in documento.regiones) {
      final rect = mapper.mapearRectangulo(region);
      final seleccionado = seleccion.contains(region.id);
      final paint = Paint()
        ..color = color.withValues(alpha: seleccionado ? 0.42 : 0.13)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = color.withValues(alpha: seleccionado ? 0.95 : 0.48)
        ..strokeWidth = seleccionado ? 2 : 1
        ..style = PaintingStyle.stroke;
      final path = Path();
      if (region.poligono.length >= 3) {
        for (var i = 0; i < region.poligono.length; i++) {
          final punto = region.poligono[i];
          final x = mapper.desplazamientoX + punto.x * mapper.escala;
          final y = mapper.desplazamientoY + punto.y * mapper.escala;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
      } else {
        path.addRect(
          Rect.fromLTWH(rect.izquierda, rect.arriba, rect.ancho, rect.alto),
        );
      }
      canvas.drawPath(path, paint);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayOcrPainter oldDelegate) =>
      oldDelegate.documento != documento ||
      oldDelegate.mapper != mapper ||
      oldDelegate.seleccion != seleccion ||
      oldDelegate.color != color;
}

class _EditarMontoOcrDialog extends StatefulWidget {
  final NumeroDetectado candidato;
  final String monedaInicial;
  final String monedaConversor;

  const _EditarMontoOcrDialog({
    required this.candidato,
    required this.monedaInicial,
    required this.monedaConversor,
  });

  @override
  State<_EditarMontoOcrDialog> createState() => _EditarMontoOcrDialogState();
}

class _EditarMontoOcrDialogState extends State<_EditarMontoOcrDialog> {
  late final TextEditingController _controller;
  late String _moneda;
  String? _error;
  bool? _interpretarComoDecimal;
  String? _textoAmbiguoConfirmado;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.candidato.texto);
    _moneda = const {'USD', 'EUR', 'USDT', 'VES'}.contains(widget.monedaInicial)
        ? widget.monedaInicial
        : 'USD';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final ambiguo = _requiereInterpretacion;
    if (ambiguo && _interpretarComoDecimal == null) {
      setState(() => _error = 'Elige si el separador indica miles o decimales');
      return;
    }
    final texto = _controller.text.trim();
    final valor = ambiguo
        ? _interpretarComoDecimal == true
              ? double.tryParse(texto.replaceAll(',', '.'))
              : double.tryParse(texto.replaceAll(',', '').replaceAll('.', ''))
        : parsearNumero(texto);
    if (valor == null || !valor.isFinite || valor <= 0) {
      setState(() => _error = 'Revisa el monto y sus separadores');
      return;
    }
    final monto = valor.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
    Navigator.pop(
      context,
      TransferenciaOcr(monto: monto.replaceAll('.', ','), moneda: _moneda),
    );
  }

  bool get _requiereInterpretacion =>
      RegExp(r'^\d{1,3}[,.]\d{3}$').hasMatch(_controller.text.trim()) &&
      _controller.text.trim().split(RegExp('[,.]')).first != '0';

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Revisar monto'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (texto) => setState(() {
            final normalizado = texto.trim();
            if (normalizado != _textoAmbiguoConfirmado) {
              _interpretarComoDecimal = null;
              _textoAmbiguoConfirmado = normalizado;
            }
            _error = null;
          }),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Monto',
            errorText: _error,
            helperText: widget.candidato.separadorAmbiguo
                ? 'Confirma si el separador representa miles o decimales.'
                : null,
          ),
        ),
        if (_requiereInterpretacion) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<bool>(
            initialValue: _interpretarComoDecimal,
            decoration: const InputDecoration(
              labelText: 'Significado del separador',
            ),
            items: const [
              DropdownMenuItem(
                value: false,
                child: Text('Miles · 1,234 = 1234'),
              ),
              DropdownMenuItem(
                value: true,
                child: Text('Decimales · 1,234 = 1,234'),
              ),
            ],
            onChanged: (value) => setState(() {
              _interpretarComoDecimal = value;
              _error = null;
            }),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _moneda,
          decoration: const InputDecoration(labelText: 'Moneda del monto'),
          items: const [
            DropdownMenuItem(value: 'VES', child: Text('VES · bolívares')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            DropdownMenuItem(value: 'USDT', child: Text('USDT · P2P')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _moneda = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _moneda == 'VES'
              ? 'Dirección: VES → ${widget.monedaConversor}.'
              : 'Dirección: $_moneda → bolívares.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirmar, child: const Text('Usar monto')),
    ],
  );
}

class PointerEventDetails {
  final Offset localPosition;

  const PointerEventDetails(this.localPosition);
}
