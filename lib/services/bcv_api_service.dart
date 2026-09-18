import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';

class BcvApiService {
  static const _baseUrl = 'https://dolar-vzla.rafnixg.dev/api/v1';
  static const _venezuelaOffset = Duration(hours: 4);
  final http.Client _client;

  BcvApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<TasaBcv> obtenerTasa() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/bcv/realtime'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error en API BCV: HTTP ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body) as List<dynamic>;

    double? usd;
    double? eur;
    DateTime? fechaUsd;
    DateTime? fechaEur;

    for (final entry in data) {
      final map = entry as Map<String, dynamic>;
      final currency = map['currency'] as String;
      final rate = (map['rate'] as num).toDouble();
      final dateStr = map['date'] as String;
      final providerDate = _parsearFechaProveedor(dateStr);

      if (currency == 'dolar') {
        usd = rate;
        fechaUsd = providerDate;
      }
      if (currency == 'euro') {
        eur = rate;
        fechaEur = providerDate;
      }
    }

    if (usd == null || eur == null || fechaUsd == null || fechaEur == null) {
      throw Exception('API no devolvió USD y EUR');
    }

    final fechaEfectivaUsd = _fechaEfectivaProveedor(fechaUsd);
    final fechaEfectivaEur = _fechaEfectivaProveedor(fechaEur);

    // Do not combine realtime values that belong to different effective days.
    if (fechaEfectivaUsd != fechaEfectivaEur) {
      throw Exception('API devolvió USD y EUR de fechas efectivas distintas');
    }

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fechaUsd,
      origen: 'api',
      fechaEfectiva: fechaEfectivaUsd,
    );
  }

  Future<double> obtenerUsdt() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/binance/realtime_ves'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener USDT: HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['median_price'] as num?)?.toDouble() ?? 0;
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    return _obtenerHistoricoComun(fechaLimite, incluirLimite: false);
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    return _obtenerHistoricoComun(fecha, incluirLimite: true);
  }

  Future<TasaBcv?> _obtenerHistoricoComun(
    DateTime fechaLimite, {
    required bool incluirLimite,
  }) async {
    final limite = _dia(fechaLimite);

    String formatDate(DateTime fecha) =>
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}T00:00:00';

    final inicio = formatDate(limite.subtract(const Duration(days: 30)));
    final fin = formatDate(limite.add(const Duration(days: 1)));

    final results = await Future.wait([
      _client
          .get(
            Uri.parse(
              '$_baseUrl/history/bcv?currency=dolar&start_date=$inicio&end_date=$fin&limit=1000&order=desc',
            ),
          )
          .timeout(const Duration(seconds: 10)),
      _client
          .get(
            Uri.parse(
              '$_baseUrl/history/bcv?currency=euro&start_date=$inicio&end_date=$fin&limit=1000&order=desc',
            ),
          )
          .timeout(const Duration(seconds: 10)),
    ]);

    final dolarRates = _extraerRates(results[0]);
    final euroRates = _extraerRates(results[1]);
    if (dolarRates.isEmpty || euroRates.isEmpty) return null;

    final usdPorFecha = _agruparPorFechaEfectiva(dolarRates);
    final eurPorFecha = _agruparPorFechaEfectiva(euroRates);
    DateTime? mejorFecha;

    for (final fecha in usdPorFecha.keys) {
      if (!eurPorFecha.containsKey(fecha)) continue;
      final permitida = incluirLimite
          ? !fecha.isAfter(limite)
          : fecha.isBefore(limite);
      if (!permitida) continue;
      if (mejorFecha == null || fecha.isAfter(mejorFecha)) {
        mejorFecha = fecha;
      }
    }

    if (mejorFecha == null) return null;
    final usd = usdPorFecha[mejorFecha]!;
    final eur = eurPorFecha[mejorFecha]!;

    return TasaBcv(
      usd: usd.valor,
      eur: eur.valor,
      usdt: 0,
      // Keep the provider timestamp for diagnostics; effective-date selection
      // is based on the shared normalized effective day above.
      fecha: usd.fechaProveedor,
      origen: 'api',
      fechaEfectiva: mejorFecha,
    );
  }

  List<Map<String, dynamic>> _extraerRates(http.Response response) {
    if (response.statusCode != 200) return [];
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final currencies = decoded['currencies'];
    if (currencies is! List) return [];
    return currencies.whereType<Map<String, dynamic>>().toList();
  }

  Map<DateTime, _ApiRate> _agruparPorFechaEfectiva(
    List<Map<String, dynamic>> rates,
  ) {
    final grouped = <DateTime, _ApiRate>{};

    for (final rate in rates) {
      final rawDate = rate['date'];
      final rawValue = rate['rate'];
      if (rawDate is! String || rawValue is! num) continue;

      try {
        final providerDate = _parsearFechaProveedor(rawDate);
        final effectiveDate = _fechaEfectivaProveedor(providerDate);
        final candidate = _ApiRate(
          valor: rawValue.toDouble(),
          fechaProveedor: providerDate,
          fechaEfectiva: effectiveDate,
        );
        final previous = grouped[effectiveDate];
        if (previous == null || providerDate.isAfter(previous.fechaProveedor)) {
          grouped[effectiveDate] = candidate;
        }
      } on FormatException {
        // Ignore malformed provider rows and evaluate the remaining history.
      }
    }

    return grouped;
  }

  DateTime _fechaEfectivaProveedor(DateTime fecha) =>
      _dia(calcularFechaEfectiva(fecha.toUtc().subtract(_venezuelaOffset)));

  DateTime _parsearFechaProveedor(String raw) {
    final parsed = DateTime.parse(raw);
    if (!_tieneZonaHoraria(raw)) {
      // Rafnix documents offset-less timestamps as UTC wall-clock components.
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
    return parsed.toUtc();
  }

  bool _tieneZonaHoraria(String raw) => RegExp(
    r'[T ]\d{2}:\d{2}.*(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw.trim());

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}

class _ApiRate {
  final double valor;
  final DateTime fechaProveedor;
  final DateTime fechaEfectiva;

  const _ApiRate({
    required this.valor,
    required this.fechaProveedor,
    required this.fechaEfectiva,
  });
}
