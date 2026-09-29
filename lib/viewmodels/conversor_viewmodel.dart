import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/cotizacion_usdt.dart';
import '../models/resultado_tasa.dart';
import '../models/tasa_bcv.dart';
import '../services/feriados_service.dart';
import '../services/tasa_repository.dart';
import '../utils/currency_labels.dart';
import '../utils/feriados_ve.dart';
import '../utils/numeros_ocr.dart';

enum ConversionDireccion { monedaAVes, vesAMoneda }

enum EstadoTasa { cargando, listo, error }

class ConversorViewmodel extends ChangeNotifier {
  final TasaRepository _repository;
  final Future<void> Function(ResultadoTasa resultado)? onRateAvailable;
  final entradaController = TextEditingController();
  int _cargaGeneracion = 0;
  int _monedaGeneracion = 0;
  bool _disposed = false;

  TasaBcv? _tasa;
  ResultadoTasa? _resultadoTasa;
  EstadoTasa _estado = EstadoTasa.cargando;
  bool _cargandoUsdt = false;
  String _error = '';
  String _errorUsdt = '';
  CotizacionUsdt? _cotizacionUsdt;
  ConversionDireccion _direccion = ConversionDireccion.monedaAVes;
  String _entrada = '';
  String _resultado = '';
  String _resultadoPreciso = '';
  String _moneda = 'USD';
  DateTime? _fechaSeleccionada;
  bool _entradaInterpretada = false;

  ConversorViewmodel({TasaRepository? repository, this.onRateAvailable})
    : _repository = repository ?? TasaRepository(),
      super();

  TasaBcv? get tasa => _tasa;
  ResultadoTasa? get resultadoTasa => _resultadoTasa;
  EstadoTasa get estado => _estado;
  String get error => _error;
  String get errorUsdt => _errorUsdt;
  ConversionDireccion get direccion => _direccion;
  String get entrada => _entrada;
  String get resultado => _resultado;
  String get resultadoPreciso => _resultadoPreciso;
  String get moneda => _moneda;
  bool get cargandoUsdt => _cargandoUsdt;
  bool get entradaBloqueada => false;
  bool get entradaInterpretada => _entradaInterpretada;
  CotizacionUsdt? get cotizacionUsdt => _cotizacionUsdt;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;
  bool get esMonedaAVes => _direccion == ConversionDireccion.monedaAVes;

  bool _tasaSiguienteDisponible = false;
  bool get tasaSiguienteDisponible => _tasaSiguienteDisponible;

  DateTime? _fechaTasaSiguiente;
  DateTime? get fechaTasaSiguiente => _fechaTasaSiguiente;

  /// Mayor fecha elegible: próxima tasa publicada o hoy en Venezuela.
  DateTime get fechaMaximaSeleccionable {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final siguiente = _fechaTasaSiguiente;
    if (siguiente != null && siguiente.isAfter(hoy)) return siguiente;
    return hoy;
  }

  double get tasaActual => _moneda == 'USDT'
      ? (_cotizacionUsdt?.valor ?? 0)
      : (_tasa?.de(_moneda) ?? 0);

  double? variacion;

  DateTime? get fechaEfectivaAplicada => _tasa?.fechaEfectiva;

  String get labelOrigen => etiquetaMoneda(esMonedaAVes ? _moneda : 'VES');
  String get labelDestino => etiquetaMoneda(esMonedaAVes ? 'VES' : _moneda);

  Future<void> cargarTasa() async {
    final generacion = ++_cargaGeneracion;
    final monedaGeneracion = _monedaGeneracion;
    final fechaSolicitada = _fechaSeleccionada;

    if (_tasa == null) _estado = EstadoTasa.cargando;
    _error = '';
    _tasaSiguienteDisponible = false;
    _fechaTasaSiguiente = null;
    variacion = null;
    _notificar();

    try {
      final TasaBcv? tasa;
      final ResultadoTasa? resultadoObtenido;
      if (fechaSolicitada != null) {
        tasa = await _repository.obtenerTasaHistorica(fechaSolicitada);
        resultadoObtenido = null;
      } else {
        final resultado = await _repository.obtenerTasaConEstado();
        tasa = resultado.tasa;
        resultadoObtenido = resultado;
      }
      if (!_sigueVigente(
        generacion: generacion,
        monedaGeneracion: monedaGeneracion,
      )) {
        return;
      }
      _resultadoTasa = resultadoObtenido;

      if (tasa == null ||
          !tasa.esValida ||
          (fechaSolicitada != null &&
              _fechaDia(tasa.fechaEfectiva).isAfter(fechaSolicitada))) {
        _error = 'Sin datos para esta fecha';
        if (fechaSolicitada != null) _tasa = null;
        _estado = _tasa == null ? EstadoTasa.error : EstadoTasa.listo;
        _limpiarResultado();
        _notificar();
        return;
      }

      _tasa = tasa;
      _estado = EstadoTasa.listo;
      _error = '';
      if (fechaSolicitada == null) _publicarTasaActual();
      if (fechaSolicitada == null) {
        _cargarFechaSiguiente(generacion, monedaGeneracion);
      }
      FeriadosService.sincronizar();
      if (_entrada.isNotEmpty) convertir(notificar: false);
      _notificar();

      // La tasa visible no espera a una operación secundaria de histórico.
      await _calcularVariacion(generacion: generacion);
    } catch (error) {
      if (!_sigueVigente(
        generacion: generacion,
        monedaGeneracion: monedaGeneracion,
      )) {
        return;
      }
      _error = error.toString();
      _estado = _tasa == null ? EstadoTasa.error : EstadoTasa.listo;
      variacion = null;
      _notificar();
    }
  }

  Future<void> _cargarFechaSiguiente(
    int generacion,
    int monedaGeneracion,
  ) async {
    try {
      final siguiente = await _repository.obtenerTasaSiguiente();
      if (!_sigueVigente(
        generacion: generacion,
        monedaGeneracion: monedaGeneracion,
      )) {
        return;
      }
      _fechaTasaSiguiente = siguiente?.fechaEfectiva;
      _tasaSiguienteDisponible = siguiente != null;
      _notificar();
    } catch (_) {
      // La consulta opcional no debe esconder la tasa actual.
    }
  }

  Future<void> _calcularVariacion({int? generacion}) async {
    final cargaGeneracion = generacion ?? _cargaGeneracion;
    final monedaGeneracion = _monedaGeneracion;
    final actual = _tasa;
    final moneda = _moneda;
    if (!_sigueVigente(
          generacion: cargaGeneracion,
          monedaGeneracion: monedaGeneracion,
        ) ||
        actual == null ||
        moneda == 'USDT') {
      variacion = null;
      return;
    }

    try {
      final tasaAnterior = await _repository.obtenerTasaAnterior(
        actual.fechaEfectiva,
      );
      if (!_sigueVigente(
            generacion: cargaGeneracion,
            monedaGeneracion: monedaGeneracion,
          ) ||
          !identical(_tasa, actual) ||
          _moneda != moneda) {
        return;
      }
      if (tasaAnterior == null || !tasaAnterior.esValida) {
        variacion = null;
      } else {
        final valorActual = actual.de(moneda);
        final valorAnterior = tasaAnterior.de(moneda);
        variacion =
            valorActual.isFinite &&
                valorAnterior.isFinite &&
                valorActual > 0 &&
                valorAnterior > 0
            ? ((valorActual - valorAnterior) / valorAnterior) * 100
            : null;
      }
      _notificar();
    } catch (_) {
      if (_sigueVigente(
        generacion: cargaGeneracion,
        monedaGeneracion: monedaGeneracion,
      )) {
        variacion = null;
        _notificar();
      }
    }
  }

  Future<void> refrescarTasa() async {
    if (_fechaSeleccionada != null) {
      await cargarTasa();
      return;
    }

    final generacion = ++_cargaGeneracion;
    final monedaGeneracion = _monedaGeneracion;
    if (_tasa == null) _estado = EstadoTasa.cargando;
    _error = '';
    _tasaSiguienteDisponible = false;
    _fechaTasaSiguiente = null;
    variacion = null;
    _notificar();

    try {
      final resultado = await _repository.refrescarTasaConEstado();
      final tasa = resultado.tasa;
      if (!_sigueVigente(
        generacion: generacion,
        monedaGeneracion: monedaGeneracion,
      )) {
        return;
      }
      if (!tasa.esValida) throw FormatException('Tasa BCV inválida');

      _tasa = tasa;
      _resultadoTasa = resultado;
      _estado = EstadoTasa.listo;
      _error = '';
      _publicarTasaActual();
      FeriadosService.sincronizar();
      if (_entrada.isNotEmpty) convertir(notificar: false);
      _notificar();
      _cargarFechaSiguiente(generacion, monedaGeneracion);
      await _calcularVariacion(generacion: generacion);
    } catch (error) {
      if (!_sigueVigente(
        generacion: generacion,
        monedaGeneracion: monedaGeneracion,
      )) {
        return;
      }
      _error = error.toString();
      _estado = _tasa == null ? EstadoTasa.error : EstadoTasa.listo;
      _notificar();
    }
  }

  Future<void> setMoneda(String moneda) async {
    final normalizada = moneda.toUpperCase();
    if (!const {'USD', 'EUR', 'USDT'}.contains(normalizada)) {
      throw ArgumentError.value(moneda, 'moneda', 'Moneda no soportada');
    }
    if (_moneda == normalizada && normalizada != 'USDT') return;

    final generacion = ++_monedaGeneracion;
    final necesitaTasaActual =
        normalizada == 'USDT' && _fechaSeleccionada != null;
    final necesitaCargaInicial = normalizada != 'USDT' && _tasa == null;
    _moneda = normalizada;
    if (necesitaTasaActual) _fechaSeleccionada = null;
    _errorUsdt = '';
    if (normalizada != 'USDT') _cargandoUsdt = false;
    variacion = null;
    _limpiarResultado();
    _notificar();

    if (necesitaTasaActual || necesitaCargaInicial) {
      await cargarTasa();
      if (!_sigueVigente(monedaGeneracion: generacion)) return;
    } else if (normalizada != 'USDT') {
      await _calcularVariacion();
      if (!_sigueVigente(monedaGeneracion: generacion)) return;
    }

    if (normalizada == 'USDT') {
      await _cargarUsdt(generacion);
      return;
    }
    if (_tasa != null && _entrada.isNotEmpty) convertir(notificar: false);
    _notificar();
  }

  Future<void> _cargarUsdt(int generacion, {bool forzar = false}) async {
    _cargandoUsdt = true;
    _errorUsdt = '';
    _notificar();
    CotizacionUsdt? cotizacion;
    try {
      cotizacion = await _repository.obtenerCotizacionUsdt(forzar: forzar);
    } catch (_) {
      cotizacion = null;
    }
    if (!_sigueVigente(monedaGeneracion: generacion) || _moneda != 'USDT') {
      return;
    }

    _cotizacionUsdt = cotizacion;
    _cargandoUsdt = false;
    _errorUsdt = cotizacion == null ? 'No hay una tasa USDT disponible' : '';
    if (_entrada.isNotEmpty) convertir(notificar: false);
    _notificar();
  }

  Future<void> refrescarUsdt() async {
    if (_moneda != 'USDT') return;
    final generacion = ++_monedaGeneracion;
    await _cargarUsdt(generacion, forzar: true);
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
    if (valor.isEmpty) _entradaInterpretada = false;
    convertir(notificar: false);
    _notificar();
  }

  void toggleDireccion() {
    _direccion = _direccion == ConversionDireccion.monedaAVes
        ? ConversionDireccion.vesAMoneda
        : ConversionDireccion.monedaAVes;

    if (_resultado.isNotEmpty) {
      _entrada = _resultado;
      _entradaInterpretada = true;
      entradaController.value = TextEditingValue(
        text: _resultado,
        selection: TextSelection.collapsed(offset: _resultado.length),
      );
      convertir(notificar: false);
    }
    _notificar();
  }

  void convertir({bool notificar = true}) {
    final tasa = tasaActual;
    final texto = _entrada.trim().replaceAll(',', '.');
    if (texto.isEmpty ||
        texto.endsWith('.') ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texto) ||
        !tasa.isFinite ||
        tasa <= 0) {
      _limpiarResultado();
      if (notificar) _notificar();
      return;
    }

    final monto = double.tryParse(texto);
    if (monto == null || !monto.isFinite || monto < 0) {
      _limpiarResultado();
      if (notificar) _notificar();
      return;
    }

    final resultado = _direccion == ConversionDireccion.monedaAVes
        ? monto * tasa
        : monto / tasa;
    if (!resultado.isFinite) {
      _limpiarResultado();
    } else {
      _resultado = resultado.toStringAsFixed(2);
      _resultadoPreciso = _resultado;
    }
    if (notificar) _notificar();
  }

  /// Aplica de forma coordinada monto, divisa y dirección detectados por OCR.
  Future<void> aplicarMontoEscaneado({
    required String monto,
    required String moneda,
  }) async {
    final valorMonto =
        parsearNumero(monto) ?? extraerNumeros(monto).firstOrNull?.valor;
    final montoNormalizado = valorMonto == null
        ? monto
        : formatearMonto(valorMonto);
    final divisa = moneda.toUpperCase().trim();
    final esVes = const {'VES', 'BS', 'BS.'}.contains(divisa);
    const monedasSoportadas = {'USD', r'US$', 'EUR', '€', 'USDT'};
    final esDivisaSoportada = monedasSoportadas.contains(divisa);
    final fechaHistoricaAnterior = _fechaSeleccionada != null;
    final generacion = ++_monedaGeneracion;

    if (esVes) {
      _direccion = ConversionDireccion.vesAMoneda;
    } else {
      _direccion = ConversionDireccion.monedaAVes;
      if (esDivisaSoportada) {
        final monedaNormalizada = switch (divisa) {
          r'US$' => 'USD',
          '€' => 'EUR',
          _ => divisa,
        };
        _moneda = monedaNormalizada;
      }
    }

    if (_moneda == 'USDT') _fechaSeleccionada = null;
    _cargandoUsdt = false;
    _errorUsdt = '';
    variacion = null;

    _entrada = montoNormalizado;
    _entradaInterpretada = true;
    entradaController.value = TextEditingValue(
      text: montoNormalizado,
      selection: TextSelection.collapsed(offset: montoNormalizado.length),
    );
    convertir(notificar: false);
    _notificar();

    final requiereTasaActual =
        _tasa == null || (_moneda == 'USDT' && fechaHistoricaAnterior);
    if (requiereTasaActual) unawaited(cargarTasa());
    if (_moneda == 'USDT') {
      unawaited(_cargarUsdt(generacion));
    } else if (!requiereTasaActual) {
      unawaited(_calcularVariacion());
    }
  }

  void _limpiarResultado() {
    _resultado = '';
    _resultadoPreciso = '';
  }

  bool _sigueVigente({int? generacion, int? monedaGeneracion}) =>
      !_disposed &&
      (generacion == null || _cargaGeneracion == generacion) &&
      (monedaGeneracion == null || _monedaGeneracion == monedaGeneracion);

  void _publicarTasaActual() {
    final callback = onRateAvailable;
    final resultado = _resultadoTasa;
    if (callback == null || resultado == null) return;
    unawaited(() async {
      try {
        await callback(resultado);
      } catch (_) {
        // An optional launcher widget must never block the currency converter.
      }
    }());
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  DateTime _fechaDia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  @override
  void dispose() {
    _disposed = true;
    _cargaGeneracion++;
    _monedaGeneracion++;
    entradaController.dispose();
    super.dispose();
  }
}
