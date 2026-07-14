import 'package:flutter/widgets.dart';
import '../models/tasa_bcv.dart';
import '../services/tasa_repository.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  final entradaController = TextEditingController();

  TasaBcv? _tasa;
  EstadoTasa _estado = EstadoTasa.cargando;
  bool _cargandoUsdt = false;
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
  bool get cargandoUsdt => _cargandoUsdt;
  bool get entradaBloqueada => _cargandoUsdt;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;

  bool get esMonedaAVes => _direccion == ConversionDireccion.monedaAVes;

  double get tasaActual => _tasa?.de(_moneda) ?? 0;

  bool get _necesitaUsdt =>
      _moneda == 'USDT' && (_tasa == null || _tasa!.usdt == 0);

  String get labelOrigen =>
      esMonedaAVes ? _moneda : 'Bolívares (VES)';
  String get labelDestino =>
      esMonedaAVes ? 'Bolívares (VES)' : _moneda;

  Future<void> cargarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    try {
      if (_fechaSeleccionada != null) {
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

  Future<void> refrescarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    try {
      _tasa = await _repository.refrescarTasa();
      _estado = EstadoTasa.listo;
      if (_entrada.isNotEmpty) convertir();
    } catch (e) {
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> setMoneda(String moneda) async {
    _moneda = moneda.toUpperCase();
    notifyListeners();

    if (_necesitaUsdt) {
      _cargandoUsdt = true;
      _resultado = '';
      notifyListeners();

      final usdt = await _repository.obtenerUsdt();
      _cargandoUsdt = false;

      if (usdt != null && usdt > 0) {
        if (_tasa != null) {
          _tasa = TasaBcv(
            usd: _tasa!.usd,
            eur: _tasa!.eur,
            usdt: usdt,
            fecha: _tasa!.fecha,
            origen: _tasa!.origen,
          );
        } else {
          _tasa = TasaBcv(
            usd: 0,
            eur: 0,
            usdt: usdt,
            fecha: DateTime.now(),
            origen: 'api',
          );
          _estado = EstadoTasa.listo;
        }
        if (_entrada.isNotEmpty) convertir();
      }
      notifyListeners();
      return;
    }

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
      entradaController.text = _resultado;
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

    var valor = _entrada.replaceAll(',', '.');
    valor = valor.replaceAll(RegExp(r'[.]$'), '');

    final monto = double.tryParse(valor);
    if (monto == null) return;

    double res;
    if (_direccion == ConversionDireccion.monedaAVes) {
      res = monto * tasaActual;
    } else {
      res = monto / tasaActual;
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
