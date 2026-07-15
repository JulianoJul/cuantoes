import 'package:flutter/widgets.dart';
import '../models/tasa_bcv.dart';
import '../services/tasa_repository.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  final entradaController = TextEditingController();
  int _cargaGeneracion = 0;

  TasaBcv? _tasa;
  EstadoTasa _estado = EstadoTasa.cargando;
  bool _cargandoUsdt = false;
  String _error = '';
  ConversionDireccion _direccion = ConversionDireccion.monedaAVes;
  String _entrada = '';
  String _resultado = '';
  String _resultadoPreciso = '';
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
  String get resultadoPreciso => _resultadoPreciso;
  String get moneda => _moneda;
  bool get cargandoUsdt => _cargandoUsdt;
  bool get entradaBloqueada => _cargandoUsdt;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;

  bool get esMonedaAVes => _direccion == ConversionDireccion.monedaAVes;

  double get tasaActual => _tasa?.de(_moneda) ?? 0;
  double? variacion;

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

    final generacion = ++_cargaGeneracion;

    try {
      TasaBcv? tasa;

      if (_fechaSeleccionada != null) {
        tasa = await _repository.obtenerTasaHistorica(_fechaSeleccionada!);
        if (_cargaGeneracion != generacion) return;
      }
      tasa ??= await _repository.obtenerTasa();
      if (_cargaGeneracion != generacion) return;

      _tasa = tasa;
      if (_fechaSeleccionada != null) {
        final sel = DateTime(
          _fechaSeleccionada!.year,
          _fechaSeleccionada!.month,
          _fechaSeleccionada!.day,
        );
        final ef = DateTime(
          tasa.fechaEfectiva.year,
          tasa.fechaEfectiva.month,
          tasa.fechaEfectiva.day,
        );
        if (ef.isBefore(sel)) {
          _fechaSeleccionada = ef;
        }
      }
      _estado = EstadoTasa.listo;
      await _calcularVariacion();
      if (_cargaGeneracion != generacion) return;
      if (_entrada.isNotEmpty) convertir();
    } catch (e) {
      if (_cargaGeneracion != generacion) return;
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> _calcularVariacion() async {
    if (_fechaSeleccionada != null || _tasa == null || _moneda == 'USDT') {
      variacion = null;
      return;
    }
    final gen = _cargaGeneracion;
    final actual = _tasa!;
    final diaAnterior = actual.fechaEfectiva.subtract(const Duration(days: 1));
    final tasaAnterior = await _repository.obtenerTasaAnterior(diaAnterior);
    if (_cargaGeneracion != gen) return;
    if (tasaAnterior == null) {
      variacion = null;
      return;
    }
    final valActual = actual.de(_moneda);
    final valAnterior = tasaAnterior.de(_moneda);
    if (valAnterior <= 0) {
      variacion = null;
      return;
    }
    variacion = ((valActual - valAnterior) / valAnterior) * 100;
  }

  Future<void> refrescarTasa() async {
    _estado = EstadoTasa.cargando;
    _error = '';
    notifyListeners();

    try {
      _tasa = await _repository.refrescarTasa();
      _estado = EstadoTasa.listo;
      await _calcularVariacion();
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
      final gen = ++_cargaGeneracion;
      _cargandoUsdt = true;
      _resultado = '';
      _resultadoPreciso = '';
      notifyListeners();

      final usdt = await _repository.obtenerUsdt();
      if (_cargaGeneracion != gen) return;
      if (_moneda != 'USDT') {
        _cargandoUsdt = false;
        notifyListeners();
        return;
      }
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
        await _calcularVariacion();
        if (_cargaGeneracion != gen) return;
        if (_entrada.isNotEmpty) convertir();
      }
      notifyListeners();
      return;
    }

    _cargandoUsdt = false;
    await _calcularVariacion();
    if (_tasa != null && _entrada.isNotEmpty) convertir();
    notifyListeners();
  }

  Future<void> seleccionarFecha(DateTime fecha) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final sel = DateTime(fecha.year, fecha.month, fecha.day);
    if (!sel.isBefore(hoy)) {
      _fechaSeleccionada = null;
    } else {
      _fechaSeleccionada = sel;
    }
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
      _resultadoPreciso = '';
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
    _resultadoPreciso = res.toStringAsFixed(4);
    notifyListeners();
  }

  @override
  void dispose() {
    entradaController.dispose();
    super.dispose();
  }
}
