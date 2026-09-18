import 'package:flutter/widgets.dart';
import '../models/tasa_bcv.dart';
import '../services/tasa_repository.dart';
import '../services/feriados_service.dart';
import '../utils/feriados_ve.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  final entradaController = TextEditingController();
  int _cargaGeneracion = 0;
  int _monedaGeneracion = 0;

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

  bool _tasaSiguienteDisponible = false;
  bool get tasaSiguienteDisponible => _tasaSiguienteDisponible;

  double get tasaActual => _tasa?.de(_moneda) ?? 0;
  double? variacion;

  DateTime? get fechaEfectivaAplicada => _tasa?.fechaEfectiva;

  bool get _necesitaUsdt =>
      _moneda == 'USDT' && (_tasa == null || _tasa!.usdt == 0);

  String get labelOrigen => esMonedaAVes ? _moneda : 'Bolívares (VES)';
  String get labelDestino => esMonedaAVes ? 'Bolívares (VES)' : _moneda;

  Future<void> cargarTasa() async {
    final generacion = ++_cargaGeneracion;
    final fechaSolicitada = _fechaSeleccionada;

    _estado = EstadoTasa.cargando;
    _error = '';
    _tasaSiguienteDisponible = false;
    variacion = null;
    notifyListeners();

    try {
      final tasa = fechaSolicitada != null
          ? await _repository.obtenerTasaHistorica(fechaSolicitada)
          : await _repository.obtenerTasa();
      if (_cargaGeneracion != generacion) return;

      if (tasa == null ||
          (fechaSolicitada != null &&
              _fechaDia(tasa.fechaEfectiva).isAfter(fechaSolicitada))) {
        _tasa = null;
        _resultado = '';
        _resultadoPreciso = '';
        _estado = EstadoTasa.error;
        _error = 'Sin datos para esta fecha';
        notifyListeners();
        return;
      }

      // El histórico no incluye USDT. Conservamos un valor USDT ya cargado
      // mientras reemplazamos únicamente las tasas BCV.
      final usdt = tasa.usdt > 0 ? tasa.usdt : (_tasa?.usdt ?? 0);
      _tasa = usdt == tasa.usdt
          ? tasa
          : TasaBcv(
              usd: tasa.usd,
              eur: tasa.eur,
              usdt: usdt,
              fecha: tasa.fecha,
              origen: tasa.origen,
              fechaEfectiva: tasa.fechaEfectiva,
            );

      if (fechaSolicitada == null) {
        _tasaSiguienteDisponible = await _repository.existeTasaSiguiente();
        if (_cargaGeneracion != generacion) return;
      }

      // Sincronizamos feriados de Google en segundo plano.
      FeriadosService.sincronizar();

      _estado = EstadoTasa.listo;
      await _calcularVariacion(generacion: generacion);
      if (_cargaGeneracion != generacion) return;
      if (_entrada.isNotEmpty && !_cargandoUsdt) convertir();
    } catch (e) {
      if (_cargaGeneracion != generacion) return;
      _tasa = null;
      _resultado = '';
      _resultadoPreciso = '';
      variacion = null;
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> _calcularVariacion({int? generacion}) async {
    final cargaGeneracion = generacion ?? _cargaGeneracion;
    final monedaGeneracion = _monedaGeneracion;
    if (_cargaGeneracion != cargaGeneracion) return;

    final actual = _tasa;
    final moneda = _moneda;
    if (actual == null || moneda == 'USDT') {
      variacion = null;
      return;
    }

    final tasaAnterior = await _repository.obtenerTasaAnterior(
      actual.fechaEfectiva,
    );
    if (_cargaGeneracion != cargaGeneracion ||
        _monedaGeneracion != monedaGeneracion ||
        !identical(_tasa, actual) ||
        _moneda != moneda) {
      return;
    }
    if (tasaAnterior == null) {
      variacion = null;
      return;
    }
    final valActual = actual.de(moneda);
    final valAnterior = tasaAnterior.de(moneda);
    if (valAnterior <= 0) {
      variacion = null;
      return;
    }
    variacion = ((valActual - valAnterior) / valAnterior) * 100;
  }

  Future<void> refrescarTasa() async {
    if (_fechaSeleccionada != null) {
      await cargarTasa();
      return;
    }

    final generacion = ++_cargaGeneracion;
    _estado = EstadoTasa.cargando;
    _error = '';
    _tasaSiguienteDisponible = false;
    variacion = null;
    notifyListeners();

    try {
      final tasa = await _repository.refrescarTasa();
      if (_cargaGeneracion != generacion) return;

      final usdt = tasa.usdt > 0 ? tasa.usdt : (_tasa?.usdt ?? 0);
      _tasa = usdt == tasa.usdt
          ? tasa
          : TasaBcv(
              usd: tasa.usd,
              eur: tasa.eur,
              usdt: usdt,
              fecha: tasa.fecha,
              origen: tasa.origen,
              fechaEfectiva: tasa.fechaEfectiva,
            );
      _tasaSiguienteDisponible = await _repository.existeTasaSiguiente();
      if (_cargaGeneracion != generacion) return;
      FeriadosService.sincronizar(); // Sync en segundo plano
      _estado = EstadoTasa.listo;
      await _calcularVariacion(generacion: generacion);
      if (_cargaGeneracion != generacion) return;
      if (_entrada.isNotEmpty && !_cargandoUsdt) convertir();
    } catch (e) {
      if (_cargaGeneracion != generacion) return;
      _tasa = null;
      _resultado = '';
      _resultadoPreciso = '';
      variacion = null;
      _estado = EstadoTasa.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> setMoneda(String moneda) async {
    final generacion = ++_monedaGeneracion;
    _moneda = moneda.toUpperCase();
    _cargandoUsdt = false;
    variacion = null;
    notifyListeners();

    if (_necesitaUsdt) {
      _cargandoUsdt = true;
      _resultado = '';
      _resultadoPreciso = '';
      notifyListeners();

      double? usdt;
      try {
        usdt = await _repository.obtenerUsdt();
      } catch (_) {
        usdt = null;
      }
      if (_monedaGeneracion != generacion) return;
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
            fechaEfectiva: _tasa!.fechaEfectiva,
          );
        } else if (_fechaSeleccionada == null) {
          _tasa = TasaBcv(
            usd: 0,
            eur: 0,
            usdt: usdt,
            fecha: DateTime.now(),
            origen: 'api',
            fechaEfectiva: fechaEfectivaActual(),
          );
          _estado = EstadoTasa.listo;
        }
        variacion = null;
        if (_entrada.isNotEmpty) convertir();
      }
      notifyListeners();
      return;
    }

    _cargandoUsdt = false;
    await _calcularVariacion();
    if (_monedaGeneracion != generacion) return;
    if (_tasa != null && _entrada.isNotEmpty) convertir();
    notifyListeners();
  }

  Future<void> seleccionarFecha(DateTime fecha) async {
    _fechaSeleccionada = DateTime(fecha.year, fecha.month, fecha.day);
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

  DateTime _fechaDia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  @override
  void dispose() {
    entradaController.dispose();
    super.dispose();
  }
}
