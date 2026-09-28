import 'dart:async';

import 'package:flutter/material.dart';

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
              Text('Preferencias', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
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
                      subtitle: const Text('Convierte los últimos dígitos en decimales al escribir'),
                      value: settings.isAutomaticComma,
                      onChanged: (_) => settings.toggleAutomaticComma(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Widget compacto', style: Theme.of(context).textTheme.titleMedium),
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
                        title: Text('Moneda mostrada'),
                        subtitle: Text('Se aplica a todos los widgets compactos.'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: settings.compactWidgetCurrency,
                        decoration: const InputDecoration(labelText: 'Divisa'),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD · dólar BCV')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR · euro BCV')),
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
}
