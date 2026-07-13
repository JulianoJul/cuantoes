class TasaBcv {
  final double usd;
  final double eur;
  final double usdt;
  final DateTime fecha;
  final String origen;

  const TasaBcv({
    required this.usd,
    required this.eur,
    required this.usdt,
    required this.fecha,
    required this.origen,
  });

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

  DateTime get fechaEfectiva {
    if (fecha.hour >= 17) {
      return DateTime(fecha.year, fecha.month, fecha.day + 1);
    }
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  Map<String, dynamic> toJson() => {
        'usd': usd,
        'eur': eur,
        'usdt': usdt,
        'fecha': fecha.toIso8601String(),
        'origen': origen,
      };

  factory TasaBcv.fromJson(Map<String, dynamic> json) => TasaBcv(
        usd: (json['usd'] as num?)?.toDouble() ?? 0,
        eur: (json['eur'] as num?)?.toDouble() ?? 0,
        usdt: (json['usdt'] as num?)?.toDouble() ?? 0,
        fecha: DateTime.parse(json['fecha'] as String),
        origen: json['origen'] as String? ?? '',
      );
}
