import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/settings_provider.dart';
import 'screens/conversor_screen.dart';
import 'services/tasa_repository.dart';
import 'services/home_widget_service.dart';
import 'services/widget_background_refresh.dart';
import 'models/resultado_tasa.dart';

import 'services/feriados_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FeriadosService.cargarCache();
  runApp(CuantoesApp(onTasaActualizada: HomeWidgetService().publicar));
  if (Platform.isAndroid) {
    unawaited(
      WidgetBackgroundRefresh.inicializarYProgramar().catchError((Object _) {}),
    );
  }
}

class CuantoesApp extends StatelessWidget {
  final TasaRepository? repository;
  final Future<void> Function(ResultadoTasa resultado)? onTasaActualizada;

  const CuantoesApp({super.key, this.repository, this.onTasaActualizada});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          const primary = Color(0xFF2563EB);
          return MaterialApp(
            title: 'Tasa BCV',
            debugShowCheckedModeBanner: false,
            locale: const Locale('es'),
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es')],
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(
                    seedColor: primary,
                    brightness: Brightness.light,
                  ).copyWith(
                    primary: primary,
                    secondary: const Color(0xFF059669),
                    surface: const Color(0xFFF8FAFC),
                  ),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              cardTheme: const CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                margin: EdgeInsets.zero,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(
                    seedColor: primary,
                    brightness: Brightness.dark,
                  ).copyWith(
                    primary: const Color(0xFFB4C5FF),
                    secondary: const Color(0xFF68DBA9),
                    surface: const Color(0xFF0B1326),
                    surfaceContainer: const Color(0xFF171F33),
                    outlineVariant: const Color(0xFF434655),
                  ),
              scaffoldBackgroundColor: const Color(0xFF0B1326),
              cardTheme: const CardThemeData(
                color: Color(0xFF171F33),
                surfaceTintColor: Colors.transparent,
                margin: EdgeInsets.zero,
              ),
              useMaterial3: true,
            ),
            home: ConversorScreen(
              repository: repository,
              onTasaActualizada: onTasaActualizada,
            ),
          );
        },
      ),
    );
  }
}
