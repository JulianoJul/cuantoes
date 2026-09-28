class CotizacionUsdt {
  final double valor;
  final DateTime fechaEfectiva;
  final DateTime obtenidaEnUtc;
  final String origen;

  const CotizacionUsdt({
    required this.valor,
    required this.fechaEfectiva,
    required this.obtenidaEnUtc,
    required this.origen,
  });

  bool get esValida => valor.isFinite && valor > 0;

  Map<String, dynamic> toJson() => {
    'valor': valor,
    'fecha_efectiva': fechaEfectiva.toIso8601String(),
    'obtenida_en_utc': obtenidaEnUtc.toIso8601String(),
    'origen': origen,
  };

  factory CotizacionUsdt.fromJson(Map<String, dynamic> json) => CotizacionUsdt(
    valor: (json['valor'] as num).toDouble(),
    fechaEfectiva: DateTime.parse(json['fecha_efectiva'] as String),
    obtenidaEnUtc: DateTime.parse(json['obtenida_en_utc'] as String),
    origen: json['origen'] as String,
  );
}
