import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyDarkMode = 'setting_dark_mode';
  static const _keyAutoComma = 'setting_auto_comma';

  bool _isDarkMode = false;
  bool _isAutomaticComma = false;

  bool get isDarkMode => _isDarkMode;
  bool get isAutomaticComma => _isAutomaticComma;

  SettingsProvider() {
    _cargarAjustes();
  }

  Future<void> _cargarAjustes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;
      _isAutomaticComma = prefs.getBool(_keyAutoComma) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, _isDarkMode);
    } catch (_) {}
  }

  Future<void> toggleAutomaticComma() async {
    _isAutomaticComma = !_isAutomaticComma;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoComma, _isAutomaticComma);
    } catch (_) {}
  }
}
