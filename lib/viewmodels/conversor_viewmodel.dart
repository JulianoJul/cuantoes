import 'package:flutter/foundation.dart';
import '../models/tasa_bcv.dart';
import '../services/tasa_repository.dart';

enum ConversionDireccion { dolarABolivar, bolivarADolar }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  TasaBcv? _tasa;
  EstadoTasa _estado = EstadoTasa.cargando;
  String _error = '';
  ConversionDireccion _direccion = ConversionDireccion.dolarABolivar;
  String _entrada = '';
  String _resultado = '';

  ConversorViewmodel({TasaRepository? repository})
      : _repository = repository ?? TasaRepository();

  TasaBcv? get tasa => _tasa;
  EstadoTasa get estado => _estado;
  String get error => _error;
  ConversionDireccion get direccion => _direccion;
  String get entrada => _entrada;
  String get resultado => _resultado;

  bool get esDolarABolivar => _direccion == ConversionDireccion.dolarABolivar;
  String get monedaOrigen => esDolarABolivar ? 'USD' : 'VES';
  String get monedaDestino => esDolarABolivar ? 'VES' : 'USD';
  String get labelOrigen => esDolarABolivar ? 'Dólares (USD)' : 'Bolívares (VES)';
  String get labelDestino => esDolarABolivar ? 'Bolívares (VES)' : 'Dólares (USD)';

  Future<void> cargarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    try {
      _tasa = await _repository.obtenerTasa();
      _estado = EstadoTasa.listo;
      if (_entrada.isNotEmpty) convertir();
    } catch (e) {
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  void setEntrada(String valor) {
    _entrada = valor;
    if (_tasa != null) convertir();
  }

  void toggleDireccion() {
    _direccion = _direccion == ConversionDireccion.dolarABolivar
        ? ConversionDireccion.bolivarADolar
        : ConversionDireccion.dolarABolivar;

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
    if (_direccion == ConversionDireccion.dolarABolivar) {
      res = monto * _tasa!.usd;
    } else {
      res = monto / _tasa!.usd;
    }

    _resultado = res.toStringAsFixed(2);
    notifyListeners();
  }
}
