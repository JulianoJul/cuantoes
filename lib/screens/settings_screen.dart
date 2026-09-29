import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/home_widget_service.dart';
import '../services/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsProvider settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Preferencias',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        settings.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                      title: const Text('Tema oscuro'),
                      subtitle: const Text('Usar una apariencia oscura'),
                      value: settings.isDarkMode,
                      onChanged: (_) => settings.toggleDarkMode(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.edit_note),
                      title: const Text('Coma automática'),
                      subtitle: const Text(
                        'Convierte los últimos dígitos en decimales al escribir',
                      ),
                      value: settings.isAutomaticComma,
                      onChanged: (_) => settings.toggleAutomaticComma(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Conversor compacto (widget)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.widgets_outlined),
                        title: Text('Moneda de conversión'),
                        subtitle: Text(
                          'Muestra cuánto vale 1,00 USD o EUR en bolívares.',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: settings.compactWidgetCurrency,
                        decoration: const InputDecoration(labelText: 'Divisa'),
                        items: const [
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (\$) → VES (Bs.)'),
                          ),
                          DropdownMenuItem(
                            value: 'EUR',
                            child: Text('EUR (€) → VES (Bs.)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          settings.setCompactWidgetCurrency(value);
                          unawaited(
                            HomeWidgetService()
                                .actualizarMonedaCompacta(value)
                                .catchError((Object _) {}),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: const Text('Valores predefinidos'),
                        subtitle: Text(
                          '${settings.widgetPresetAmounts.join('  ·  ')}\n'
                          'Botones del conversor rápido 4×2',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () =>
                            _editarValoresPredefinidos(context, settings),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editarValoresPredefinidos(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final values = await showDialog<List<int>>(
      context: context,
      builder: (_) =>
          _PresetValuesDialog(initialValues: settings.widgetPresetAmounts),
    );
    if (values == null || !context.mounted) return;

    await settings.setWidgetPresetAmounts(values);
    await HomeWidgetService().actualizarValoresPredefinidos(values);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valores del widget actualizados')),
    );
  }
}

class _PresetValuesDialog extends StatefulWidget {
  final List<int> initialValues;

  const _PresetValuesDialog({required this.initialValues});

  @override
  State<_PresetValuesDialog> createState() => _PresetValuesDialogState();
}

class _PresetValuesDialogState extends State<_PresetValuesDialog> {
  late final List<TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = widget.initialValues
        .map((amount) => TextEditingController(text: '$amount'))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Valores predefinidos'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Elige cuatro montos distintos para los botones del widget.',
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
            _controllers.length,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                child: TextField(
                  key: Key('widget-preset-$index'),
                  controller: _controllers[index],
                  autofocus: index == 0,
                  keyboardType: TextInputType.number,
                  textInputAction: index == _controllers.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: '${index + 1}'),
                ),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _guardar, child: const Text('Guardar')),
    ],
  );

  void _guardar() {
    final parsed = _controllers
        .map((controller) => int.tryParse(controller.text))
        .toList();
    if (parsed.any((value) => value == null || value <= 0)) {
      setState(() => _error = 'Escribe cuatro valores mayores que cero.');
      return;
    }
    final amounts = parsed.cast<int>();
    if (amounts.toSet().length != amounts.length) {
      setState(() => _error = 'Los cuatro valores deben ser distintos.');
      return;
    }
    Navigator.pop(context, amounts);
  }
}
