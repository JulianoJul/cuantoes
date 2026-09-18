import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/feriados_ve.dart';

class FeriadosService {
  static const _googleCalendarUrl =
      'https://calendar.google.com/calendar/ical/es.ve%23holiday%40group.v.calendar.google.com/public/basic.ics';
  static const _cacheKey = 'feriados_google_cache';
  static const _lastSyncKey = 'feriados_google_last_sync';

  /// Carga el caché local al inicio de la aplicación para que esté disponible síncronamente.
  static Future<void> cargarCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_cacheKey);
    if (data != null) {
      setFeriadosGoogle(data.toSet());
    }
  }

  /// Descarga y parsea el archivo ICS desde Google Calendar si es necesario.
  static Future<void> sincronizar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(_lastSyncKey);

      // Sincronizar solo una vez al día para evitar peticiones innecesarias
      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        final ahora = DateTime.now().toUtc();
        if (ahora.difference(lastSync).inDays < 1) {
          return;
        }
      }

      final response = await http
          .get(Uri.parse(_googleCalendarUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(utf8.decode(response.bodyBytes));
        final feriados = <String>{};
        bool inEvent = false;

        for (final line in lines) {
          if (line.startsWith('BEGIN:VEVENT')) {
            inEvent = true;
          } else if (line.startsWith('END:VEVENT')) {
            inEvent = false;
          } else if (inEvent && line.startsWith('DTSTART;VALUE=DATE:')) {
            final dateStr = line.split(':')[1].trim();
            if (dateStr.length == 8) {
              feriados.add(dateStr);
            }
          }
        }

        if (feriados.isNotEmpty) {
          // Guardar en SharedPreferences
          await prefs.setStringList(_cacheKey, feriados.toList());
          await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
          
          // Actualizar variable en memoria
          setFeriadosGoogle(feriados);
        }
      }
    } catch (_) {
      // Si falla la red, no hacemos nada, la app seguirá usando el caché o el fallback matemático.
    }
  }
}
