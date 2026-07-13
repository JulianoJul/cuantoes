import 'package:flutter/widgets.dart';
import '../models/tasa_bcv.dart';
import '../models/tasa_usdt.dart';
import '../services/tasa_repository.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

enum FuenteTasa { bcv, usdt }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  final entradaController = TextEditingController();

  TasaBcv? _tasa;
  TasaUsdt? _tasaUsdt;
  EstadoTasa _estado = EstadoTasa.cargando;
  String _error = '';
  ConversionDireccion _direccion = ConversionDireccion.monedaAVes;
  String _entrada = '';
  String _resultado = '';
  String _moneda = 'USD';
  DateTime? _fechaSeleccionada;
  FuenteTasa _fuente = FuenteTasa.bcv;

  ConversorViewmodel({TasaRepository? repository})
      : _repository = repository ?? TasaRepository();

  TasaBcv? get tasa => _tasa;
  TasaUsdt? get tasaUsdt => _tasaUsdt;
  EstadoTasa get estado => _estado;
  String get error => _error;
  ConversionDireccion get direccion => _direccion;
  String get entrada => _entrada;
  String get resultado => _resultado;
  String get moneda => _moneda;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;
  FuenteTasa get fuente => _fuente;

  bool get esBcv => _fuente == FuenteTasa.bcv;
  bool get esMonedaAVes => _direccion == ConversionDireccion.monedaAVes;
  bool get esFechaHoy =>
      _fechaSeleccionada == null ||
      _fechaSeleccionada!.day == DateTime.now().day &&
          _fechaSeleccionada!.month == DateTime.now().month &&
          _fechaSeleccionada!.year == DateTime.now().year;

  double get tasaActual {
    if (_fuente == FuenteTasa.usdt) {
      return _tasaUsdt?.usdt ?? 0;
    }
    return _tasa?.de(_moneda) ?? 0;
  }

  String get labelOrigen =>
      esMonedaAVes ? _moneda : 'Bolívares (VES)';
  String get labelDestino =>
      esMonedaAVes ? 'Bolívares (VES)' : _moneda;

  Future<void> cargarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    final errores = <String>[];

    try {
      if (_fechaSeleccionada != null && !esFechaHoy) {
        final historica =
            await _repository.obtenerTasaHistorica(_fechaSeleccionada!);
        if (historica != null) {
          _tasa = historica;
        } else {
          errores.add('Sin datos para esta fecha');
        }
      } else {
        _tasa = await _repository.obtenerTasa();
      }
    } catch (e) {
      errores.add('bcv: $e');
    }

    if (_fechaSeleccionada == null || esFechaHoy) {
      final usdt = await _repository.obtenerTasaUsdt();
      if (usdt != null) {
        _tasaUsdt = usdt;
      }
    }

    if (_tasa != null) {
      _estado = EstadoTasa.listo;
      if (_entrada.isNotEmpty) convertir();
    } else if (_tasaUsdt != null && _fuente == FuenteTasa.usdt) {
      _estado = EstadoTasa.listo;
      if (_entrada.isNotEmpty) convertir();
    } else {
      _estado = EstadoTasa.error;
      _error = errores.isNotEmpty ? errores.join(' | ') : 'Error al obtener tasas';
    }

    notifyListeners();
  }

  void setFuente(FuenteTasa fuente) {
    _fuente = fuente;
    if (fuente == FuenteTasa.usdt) {
      _moneda = 'USDT';
    } else if (_moneda == 'USDT') {
      _moneda = 'USD';
    }
    if (_entrada.isNotEmpty) convertir();
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
    if (_tasa != null || _tasaUsdt != null) convertir();
  }

  void toggleDireccion() {
    _direccion = _direccion == ConversionDireccion.monedaAVes
        ? ConversionDireccion.vesAMoneda
        : ConversionDireccion.monedaAVes;

    if ((_tasa != null || _tasaUsdt != null) && _resultado.isNotEmpty) {
      _entrada = _resultado;
      entradaController.text = _resultado;
      convertir();
    }
    notifyListeners();
  }

  void convertir() {
    if (_entrada.isEmpty) {
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

    final rate = tasaActual;
    if (rate <= 0) {
      _resultado = '';
      notifyListeners();
      return;
    }

    double res;
    if (_direccion == ConversionDireccion.monedaAVes) {
      res = monto * rate;
    } else {
      res = monto / rate;
    }

    _resultado = res.toStringAsFixed(2);
    notifyListeners();
  }

  @override
  void dispose() {
    entradaController.dispose();
    super.dispose();
  }
}
