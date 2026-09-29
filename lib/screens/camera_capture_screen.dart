import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _cameraImageChannel = MethodChannel('ve.cuantoes/camera_image');

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  static const _ratioFotoHorizontal = 4 / 3;
  static const _ratioFotoVertical = 3 / 4;

  CameraController? _controller;
  String? _error;
  bool _capturando = false;
  bool _inicializando = false;
  bool _activa = true;
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_inicializar());
  }

  Future<void> _inicializar() async {
    if (_inicializando || !_activa) return;
    _inicializando = true;
    final generacion = ++_generacion;
    if (mounted) setState(() => _error = null);
    CameraController? candidato;
    try {
      final camaras = await availableCameras();
      if (!_sigueActiva(generacion)) return;
      if (camaras.isEmpty) {
        setState(() => _error = 'No hay cámaras disponibles');
        return;
      }

      final trasera = camaras.firstWhere(
        (camara) => camara.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      candidato = CameraController(
        trasera,
        // CameraX selecciona la resolución de Preview e ImageCapture con el
        // mismo preset. 1080p da detalle suficiente para OCR; el encuadre 4:3
        // se recorta después tanto en la vista como en el JPEG final.
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await candidato.initialize();
      if (!_sigueActiva(generacion)) {
        await candidato.dispose();
        candidato = null;
        return;
      }
      setState(() => _controller = candidato);
      candidato = null;
    } on CameraException catch (e) {
      await candidato?.dispose();
      if (_sigueActiva(generacion)) {
        setState(() => _error = e.description ?? 'No se pudo abrir la cámara');
      }
    } catch (_) {
      await candidato?.dispose();
      if (_sigueActiva(generacion)) {
        setState(() => _error = 'No se pudo abrir la cámara');
      }
    } finally {
      if (_generacion == generacion) _inicializando = false;
    }
  }

  bool _sigueActiva(int generacion) =>
      mounted && _activa && _generacion == generacion;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activa = true;
      if (_controller == null) unawaited(_inicializar());
      return;
    }

    _activa = false;
    _generacion++;
    _inicializando = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    if (mounted) setState(() => _capturando = false);
  }

  Future<void> _capturar() async {
    final controller = _controller;
    if (controller == null || _capturando) return;

    setState(() => _capturando = true);
    try {
      final foto = await controller.takePicture();
      if (!mounted || !identical(_controller, controller)) return;
      final rutaAjustada = await _recortarFoto(
        foto,
        _aspectRatioObjetivo(controller),
      );
      if (!mounted || !identical(_controller, controller)) return;
      Navigator.pop(context, rutaAjustada);
    } on PlatformException catch (_) {
      if (mounted) {
        setState(() => _capturando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo ajustar la foto al encuadre 4:3. Intenta otra vez.',
            ),
          ),
        );
      }
    } on FormatException catch (_) {
      if (mounted) {
        setState(() => _capturando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo preparar la foto para escanear.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _capturando = false;
          _error = 'No se pudo capturar la foto';
        });
      }
    }
  }

  Future<String> _recortarFoto(XFile foto, double aspectRatio) async {
    if (!Platform.isAndroid) return foto.path;
    final rutaRecortada = await _cameraImageChannel.invokeMethod<String>(
      'cropToAspectRatio',
      {'path': foto.path, 'aspectRatio': aspectRatio},
    );
    if (rutaRecortada == null || rutaRecortada.isEmpty) {
      throw const FormatException('No se pudo preparar la foto para OCR');
    }
    try {
      await File(foto.path).delete();
    } on FileSystemException {
      // La imagen recortada ya está guardada; limpiar el original es opcional.
    }
    return rutaRecortada;
  }

  bool _esHorizontal(CameraController controller) => const {
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  }.contains(controller.value.deviceOrientation);

  double _aspectRatioObjetivo(CameraController controller) =>
      _esHorizontal(controller) ? _ratioFotoHorizontal : _ratioFotoVertical;

  Widget _visorCuatroATres(CameraController controller) {
    final horizontal = _esHorizontal(controller);
    final aspectRatioMarco = horizontal
        ? _ratioFotoHorizontal
        : _ratioFotoVertical;
    // CameraPreview ya adapta la orientación del sensor. Darle exactamente
    // esa proporción y recortar el excedente evita deformar la textura.
    final aspectRatioOrigen = horizontal
        ? controller.value.aspectRatio
        : 1 / controller.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatioMarco,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final anchoMarco = constraints.maxWidth;
            final altoMarco = constraints.maxHeight;
            final anchoOrigen = aspectRatioOrigen > aspectRatioMarco
                ? altoMarco * aspectRatioOrigen
                : anchoMarco;
            final altoOrigen = anchoOrigen / aspectRatioOrigen;

            return Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  minWidth: anchoOrigen,
                  maxWidth: anchoOrigen,
                  minHeight: altoOrigen,
                  maxHeight: altoOrigen,
                  child: SizedBox(
                    width: anchoOrigen,
                    height: altoOrigen,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _generacion++;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('Escanear precio'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _inicializando ? null : _inicializar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _visorCuatroATres(controller)),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Encuadra el texto dentro del marco 4:3',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FloatingActionButton(
                    onPressed: _capturar,
                    child: _capturando
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
    );
  }
}
