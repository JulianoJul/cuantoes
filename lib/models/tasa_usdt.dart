class TasaUsdt {
  final double usdt;
  final double promedio;
  final DateTime fecha;

  const TasaUsdt({
    required this.usdt,
    required this.promedio,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'usdt': usdt,
        'promedio': promedio,
        'fecha': fecha.toIso8601String(),
      };

  factory TasaUsdt.fromJson(Map<String, dynamic> json) => TasaUsdt(
        usdt: (json['usdt'] as num).toDouble(),
        promedio: (json['promedio'] as num).toDouble(),
        fecha: DateTime.parse(json['fecha'] as String),
      );
}
