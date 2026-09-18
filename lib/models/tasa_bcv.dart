import '../utils/feriados_ve.dart';

class TasaBcv {
  final double usd;
  final double eur;
  final double usdt;
  final DateTime fecha;
  final String origen;
  final DateTime fechaEfectiva;

  const TasaBcv({
    required this.usd,
    required this.eur,
    required this.usdt,
    required this.fecha,
    required this.origen,
    required this.fechaEfectiva,
  });

  /// Crea una TasaBcv con fechaEfectiva calculada desde la hora actual
  /// en Venezuela (UTC-4). Usar para tasas en tiempo real (API/scraping).
  factory TasaBcv.actual({
    required double usd,
    required double eur,
    required double usdt,
    required DateTime fecha,
    required String origen,
  }) {
    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: usdt,
      fecha: fecha,
      origen: origen,
      fechaEfectiva: fechaEfectivaActual(),
    );
  }

  double de(String moneda) {
    switch (moneda.toUpperCase()) {
      case 'USD':
        return usd;
      case 'EUR':
        return eur;
      case 'USDT':
        return usdt;
      default:
        throw ArgumentError('Moneda no soportada: $moneda');
    }
  }

  Map<String, dynamic> toJson() => {
        'usd': usd,
        'eur': eur,
        'usdt': usdt,
        'fecha': fecha.toIso8601String(),
        'origen': origen,
        'fecha_efectiva': fechaEfectiva.toIso8601String(),
      };

  factory TasaBcv.fromJson(Map<String, dynamic> json) {
    final fecha = DateTime.parse(json['fecha'] as String);
    return TasaBcv(
      usd: (json['usd'] as num?)?.toDouble() ?? 0,
      eur: (json['eur'] as num?)?.toDouble() ?? 0,
      usdt: (json['usdt'] as num?)?.toDouble() ?? 0,
      fecha: fecha,
      origen: json['origen'] as String? ?? '',
      fechaEfectiva: json['fecha_efectiva'] != null
          ? DateTime.parse(json['fecha_efectiva'] as String)
          : calcularFechaEfectiva(fecha),
    );
  }
}
