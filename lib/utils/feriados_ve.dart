Set<int> _feriadosFijos = {1, 19, 24, 5, 25};

// Caché en memoria de los feriados obtenidos desde Google Calendar
Set<String> feriadosGoogleCache = {};

void setFeriadosGoogle(Set<String> feriados) {
  feriadosGoogleCache = feriados;
}

int _feriadoMes(int dia) {
  const meses = <int, int>{
    1: 1,
    19: 4,
    24: 6,
    5: 7,
    25: 12,
  };
  return meses[dia] ?? 0;
}

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

DateTime _sumarDias(DateTime dt, int days) => dt.add(Duration(days: days));

bool esFeriadoBancario(DateTime fecha) {
  final d = fecha.day;
  final m = fecha.month;

  // 1. Verificamos primero la fuente primaria (Google Calendar) si está disponible
  if (feriadosGoogleCache.isNotEmpty) {
    final dateStr =
        '${fecha.year}${m.toString().padLeft(2, '0')}${d.toString().padLeft(2, '0')}';
    if (feriadosGoogleCache.contains(dateStr)) return true;
  }

  // 2. Si no está en Google, usamos la lógica de fallback (fijos + pascua)
  if (_feriadosFijos.contains(d) && _feriadoMes(d) == m) return true;

  final pascua = _calcularPascua(fecha.year);

  final carnavalLunes = _sumarDias(pascua, -48);
  final carnavalMartes = _sumarDias(pascua, -47);
  final juevesSanto = _sumarDias(pascua, -3);
  final viernesSanto = _sumarDias(pascua, -2);

  return fecha == carnavalLunes ||
      fecha == carnavalMartes ||
      fecha == juevesSanto ||
      fecha == viernesSanto;
}

DateTime proximoDiaHabil(DateTime fecha) {
  var ef = DateTime(fecha.year, fecha.month, fecha.day);
  while (ef.weekday == DateTime.saturday ||
      ef.weekday == DateTime.sunday ||
      esFeriadoBancario(ef)) {
    ef = ef.add(const Duration(days: 1));
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
  var ef = DateTime(fecha.year, fecha.month, fecha.day);
  if (fecha.hour >= 14) {
    ef = ef.add(const Duration(days: 1));
  }
  return proximoDiaHabil(ef);
}

/// Fecha efectiva actual según la hora en Venezuela (UTC-4).
DateTime fechaEfectivaActual() {
  return calcularFechaEfectiva(ahoraVenezuela());
}
