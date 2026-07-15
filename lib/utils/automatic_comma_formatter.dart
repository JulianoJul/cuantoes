import 'package:flutter/services.dart';

class AutomaticCommaFormatter extends TextInputFormatter {
  final bool active;

  AutomaticCommaFormatter({required this.active});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!active) return newValue;

    // Si el usuario intentó borrar todo, dejarlo en 0,00
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '0,00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    // Extraer solo dígitos numéricos
    final cleanDigits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '0,00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    // Convertir a decimal (ej: 15 -> 0.15, 150 -> 1.50)
    final value = double.parse(cleanDigits) / 100.0;
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
