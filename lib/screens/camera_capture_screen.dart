import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
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
        ResolutionPreset.high,
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
      Navigator.pop(context, foto.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _capturando = false;
          _error = 'No se pudo capturar la foto';
        });
      }
    }
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
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
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
