const _feriadosFijos = <({int month, int day})>{
  (month: 1, day: 1),
  (month: 4, day: 19),
  (month: 5, day: 1),
  (month: 6, day: 24),
  (month: 7, day: 5),
  (month: 10, day: 24),
  (month: 12, day: 25),
  (month: 12, day: 31),
};

// Caché en memoria de los feriados obtenidos desde Google Calendar
Set<String> feriadosGoogleCache = {};

void setFeriadosGoogle(Set<String> feriados) {
  feriadosGoogleCache = feriados;
}

DateTime _soloFecha(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

bool _mismaFecha(DateTime primera, DateTime segunda) =>
    primera.year == segunda.year &&
    primera.month == segunda.month &&
    primera.day == segunda.day;

DateTime _calcularPascua(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, mes, dia);
}

DateTime _sumarDias(DateTime fecha, int days) =>
    DateTime(fecha.year, fecha.month, fecha.day + days);

bool esFeriadoBancario(DateTime fecha) {
  final dia = _soloFecha(fecha);

  // 1. Verificamos primero la fuente primaria (Google Calendar) si está disponible
  if (feriadosGoogleCache.isNotEmpty) {
    final dateStr =
        '${dia.year}${dia.month.toString().padLeft(2, '0')}${dia.day.toString().padLeft(2, '0')}';
    if (feriadosGoogleCache.contains(dateStr)) return true;
  }

  // 2. Si no está en Google, usamos la lógica de fallback (fijos + pascua)
  if (_feriadosFijos.contains((month: dia.month, day: dia.day))) return true;

  final pascua = _calcularPascua(dia.year);

  final carnavalLunes = _sumarDias(pascua, -48);
  final carnavalMartes = _sumarDias(pascua, -47);
  final juevesSanto = _sumarDias(pascua, -3);
  final viernesSanto = _sumarDias(pascua, -2);

  return _mismaFecha(dia, carnavalLunes) ||
      _mismaFecha(dia, carnavalMartes) ||
      _mismaFecha(dia, juevesSanto) ||
      _mismaFecha(dia, viernesSanto);
}

DateTime proximoDiaHabil(DateTime fecha) {
  var ef = _soloFecha(fecha);
  while (ef.weekday == DateTime.saturday ||
      ef.weekday == DateTime.sunday ||
      esFeriadoBancario(ef)) {
    ef = _sumarDias(ef, 1);
  }
  return ef;
}

/// Venezuela = UTC-4 (sin horario de verano).
const _offsetVenezuela = Duration(hours: 4);

/// Hora actual en Venezuela (UTC-4), independiente de la zona del dispositivo.
DateTime ahoraVenezuela() {
  return DateTime.now().toUtc().subtract(_offsetVenezuela);
}

/// Calcula la fecha efectiva BCV a partir de una fecha/hora de referencia.
/// Si la hora es ≥ 14, la tasa aplica para el siguiente día hábil.
DateTime calcularFechaEfectiva(DateTime fecha) {
  var ef = _soloFecha(fecha);
  if (fecha.hour >= 14) {
    ef = _sumarDias(ef, 1);
  }
  return proximoDiaHabil(ef);
}

/// Fecha efectiva actual según la hora en Venezuela (UTC-4).
DateTime fechaEfectivaActual() {
  return calcularFechaEfectiva(ahoraVenezuela());
}
