import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tasa_bcv.dart';

class BcvCacheService {
  static const _keyPrefix = 'tasa_bcv_cache_';

  String _keyFecha(DateTime fecha) =>
      '$_keyPrefix${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<TasaBcv?> obtenerTasa() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    String? lastKey;
    for (final k in keys) {
      if (k.startsWith(_keyPrefix)) {
        if (lastKey == null || k.compareTo(lastKey) > 0) {
          lastKey = k;
        }
      }
    }
    if (lastKey == null) return null;
    final data = prefs.getString(lastKey);
    if (data == null) return null;
    final json = jsonDecode(data) as Map<String, dynamic>;
    return TasaBcv.fromJson(json);
  }

  Future<TasaBcv?> obtenerTasaPorFecha(DateTime fecha) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFecha(fecha));
    if (data == null) return null;
    final json = jsonDecode(data) as Map<String, dynamic>;
    return TasaBcv.fromJson(json);
  }

  Future<void> guardarTasa(TasaBcv tasa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyFecha(tasa.fechaEfectiva), jsonEncode(tasa.toJson()));
  }


}
