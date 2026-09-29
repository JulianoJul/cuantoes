import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const defaultWidgetPresetAmounts = [1, 10, 50, 100];

  static const _keyDarkMode = 'setting_dark_mode';
  static const _keyAutoComma = 'setting_auto_comma';
  static const _keyCompactWidgetCurrency = 'setting_widget_compact_currency';
  static const _keyWidgetPresetAmounts = 'setting_widget_preset_amounts';

  bool _isDarkMode = false;
  bool _isAutomaticComma = false;
  String _compactWidgetCurrency = 'USD';
  List<int> _widgetPresetAmounts = [...defaultWidgetPresetAmounts];

  bool get isDarkMode => _isDarkMode;
  bool get isAutomaticComma => _isAutomaticComma;
  String get compactWidgetCurrency => _compactWidgetCurrency;
  List<int> get widgetPresetAmounts => List.unmodifiable(_widgetPresetAmounts);

  SettingsProvider() {
    _cargarAjustes();
  }

  Future<void> _cargarAjustes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;
      _isAutomaticComma = prefs.getBool(_keyAutoComma) ?? false;
      _compactWidgetCurrency =
          prefs.getString(_keyCompactWidgetCurrency) == 'EUR' ? 'EUR' : 'USD';
      final savedPresets = prefs
          .getStringList(_keyWidgetPresetAmounts)
          ?.map(int.tryParse)
          .whereType<int>()
          .toList();
      if (_validPresetAmounts(savedPresets)) {
        _widgetPresetAmounts = savedPresets!;
      }
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

  Future<void> setCompactWidgetCurrency(String currency) async {
    if (!const {'USD', 'EUR'}.contains(currency)) return;
    _compactWidgetCurrency = currency;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCompactWidgetCurrency, currency);
    } catch (_) {}
  }

  Future<void> setWidgetPresetAmounts(List<int> amounts) async {
    if (!_validPresetAmounts(amounts)) return;
    _widgetPresetAmounts = List.of(amounts);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _keyWidgetPresetAmounts,
        amounts.map((amount) => '$amount').toList(),
      );
    } catch (_) {}
  }

  static bool _validPresetAmounts(List<int>? amounts) =>
      amounts != null &&
      amounts.length == 4 &&
      amounts.toSet().length == 4 &&
      amounts.every((amount) => amount > 0 && amount <= 999999);
}
