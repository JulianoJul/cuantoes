import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tasa_bcv.dart';

class BcvCacheService {
  static const _key = 'tasa_bcv_cache';

  Future<TasaBcv?> obtenerTasa() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;

    final json = jsonDecode(data) as Map<String, dynamic>;
    return TasaBcv.fromJson(json);
  }

  Future<void> guardarTasa(TasaBcv tasa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(tasa.toJson()));
  }
}
