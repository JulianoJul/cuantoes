import 'package:flutter/foundation.dart';
import '../models/tasa_bcv.dart';
import '../services/tasa_repository.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;

  TasaBcv? _tasa;
  EstadoTasa _estado = EstadoTasa.cargando;
  String _error = '';
  ConversionDireccion _direccion = ConversionDireccion.monedaAVes;
  String _entrada = '';
  String _resultado = '';
  String _moneda = 'USD';
  DateTime? _fechaSeleccionada;

  ConversorViewmodel({TasaRepository? repository})
      : _repository = repository ?? TasaRepository();

  TasaBcv? get tasa => _tasa;
  EstadoTasa get estado => _estado;
  String get error => _error;
  ConversionDireccion get direccion => _direccion;
  String get entrada => _entrada;
  String get resultado => _resultado;
  String get moneda => _moneda;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;

  bool get esMonedaAVes => _direccion == ConversionDireccion.monedaAVes;
  bool get esFechaHoy =>
      _fechaSeleccionada == null ||
      _fechaSeleccionada!.day == DateTime.now().day &&
          _fechaSeleccionada!.month == DateTime.now().month &&
          _fechaSeleccionada!.year == DateTime.now().year;

  double get tasaActual => _tasa?.de(_moneda) ?? 0;

  String get labelOrigen =>
      esMonedaAVes ? _moneda : 'Bolívares (VES)';
  String get labelDestino =>
      esMonedaAVes ? 'Bolívares (VES)' : _moneda;

  Future<void> cargarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    try {
      if (_fechaSeleccionada != null && !esFechaHoy) {
        final historica =
            await _repository.obtenerTasaHistorica(_fechaSeleccionada!);
        if (historica != null) {
          _tasa = historica;
          _estado = EstadoTasa.listo;
        } else {
          _estado = EstadoTasa.error;
          _error = 'Sin datos para esta fecha';
        }
      } else {
        _tasa = await _repository.obtenerTasa();
        _estado = EstadoTasa.listo;
      }

      if (_entrada.isNotEmpty) convertir();
    } catch (e) {
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  void setMoneda(String moneda) {
    _moneda = moneda.toUpperCase();
    if (_tasa != null && _entrada.isNotEmpty) convertir();
    notifyListeners();
  }

  Future<void> seleccionarFecha(DateTime fecha) async {
    _fechaSeleccionada = fecha;
    await cargarTasa();
  }

  Future<void> volverAHoy() async {
    _fechaSeleccionada = null;
    await cargarTasa();
  }

  void setEntrada(String valor) {
    _entrada = valor;
    if (_tasa != null) convertir();
  }

  void toggleDireccion() {
    _direccion = _direccion == ConversionDireccion.monedaAVes
        ? ConversionDireccion.vesAMoneda
        : ConversionDireccion.monedaAVes;

    if (_tasa != null && _resultado.isNotEmpty) {
      _entrada = _resultado;
      convertir();
    }
    notifyListeners();
  }

  void convertir() {
    if (_tasa == null || _entrada.isEmpty) {
      _resultado = '';
      notifyListeners();
      return;
    }

    final monto = double.tryParse(_entrada.replaceAll(',', '.'));
    if (monto == null) {
      _resultado = '';
      notifyListeners();
      return;
    }

    double res;
    if (_direccion == ConversionDireccion.monedaAVes) {
      res = monto * tasaActual;
    } else {
      res = monto / tasaActual;
    }

    _resultado = res.toStringAsFixed(2);
    notifyListeners();
  }
}
