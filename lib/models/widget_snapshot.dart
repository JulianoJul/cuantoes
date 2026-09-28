import 'resultado_tasa.dart';

/// Values shared with Android RemoteViews through home_widget preferences.
class WidgetSnapshot {
  static const version = 2;
  static const keyPayload = 'widget_snapshot_payload';
  static const keyVersion = 'widget_snapshot_version';
  static const keyUsd = 'widget_usd_rate';
  static const keyEur = 'widget_eur_rate';
  static const keyEffectiveDate = 'widget_effective_date';
  static const keyValidatedAt = 'widget_validated_at';
  static const keySource = 'widget_source';
  static const keyStatus = 'widget_status';
  static const keyCompactCurrency = 'widget_compact_currency';

  final String usd;
  final String eur;
  final String effectiveDate;
  final String validatedAt;
  final String source;
  final String status;
  final DateTime? validatedAtUtc;

  const WidgetSnapshot({
    required this.usd,
    required this.eur,
    required this.effectiveDate,
    required this.validatedAt,
    required this.source,
    required this.status,
    this.validatedAtUtc,
  });

  Map<String, Object?> toJson() => {
    'version': version,
    'usd': usd,
    'eur': eur,
    'effectiveDate': effectiveDate,
    'validatedAt': validatedAt,
    'validatedAtUtc': validatedAtUtc?.toUtc().toIso8601String(),
    'source': source,
    'status': status,
  };

  factory WidgetSnapshot.fromResultadoTasa(ResultadoTasa resultado) {
    final tasa = resultado.tasa;
    final momento = resultado.ultimaValidacionExitosaUtc;
    final validatedAt = momento == null
        ? 'Validación desconocida'
        : 'Validada ${_fechaHora(_horaVenezuela(momento))}';
    final status = resultado.errorActualizacion != null
        ? resultado.frescura == EstadoFrescuraTasa.antigua
              ? 'No se pudo actualizar · se conserva una tasa antigua; verifica antes de usar'
              : 'No se pudo actualizar · se conserva la tasa disponible'
        : resultado.frescura == EstadoFrescuraTasa.antigua
        ? 'Fecha efectiva antigua · verifica el valor'
        : resultado.vieneDeCache
        ? 'Tasa guardada · $validatedAt'
        : validatedAt;

    return WidgetSnapshot(
      usd: _formatearTasa(tasa.usd),
      eur: _formatearTasa(tasa.eur),
      effectiveDate: _fecha(tasa.fechaEfectiva),
      validatedAt: validatedAt,
      source: _nombreFuente(tasa.origen),
      status: status,
      validatedAtUtc: momento,
    );
  }

  static DateTime _horaVenezuela(DateTime fecha) =>
      fecha.toUtc().subtract(const Duration(hours: 4));

  static String _formatearTasa(double value) {
    final raw = value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
    final partes = raw.split('.');
    final entero = partes.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return partes.length == 1 ? entero : '$entero,${partes.last}';
  }

  static String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  static String _fechaHora(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} '
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  static String _nombreFuente(String source) => switch (source) {
    'dolarapi' => 'DolarAPI',
    'bcv_today' => 'BCV Today',
    'chitty_bcv' => 'Chitty BCV',
    _ => source.isEmpty ? 'BCV' : source,
  };
}
