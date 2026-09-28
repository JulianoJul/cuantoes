import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:cuantoes/main.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> setUpViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  String cacheKey(DateTime fecha) {
    return 'tasa_bcv_cache_${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  testWidgets('App muestra tasa desde cache', (WidgetTester tester) async {
    await setUpViewport(tester);

    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechaActual = _diaHabilAnterior(hoy);
    final manana = hoy.add(const Duration(days: 1));
    final consultaReciente = DateTime.now().toUtc().subtract(
      const Duration(minutes: 1),
    );

    SharedPreferences.setMockInitialValues({
      cacheKey(fechaActual): jsonEncode({
        'usd': 72.5,
        'eur': 80.0,
        'usdt': 0,
        'fecha': fechaActual.toIso8601String(),
        'origen': 'api',
        'fecha_efectiva': fechaActual.toIso8601String(),
      }),
      cacheKey(manana): jsonEncode({
        'usd': 172.5,
        'eur': 180.0,
        'usdt': 0,
        'fecha': manana.toIso8601String(),
        'origen': 'api',
        'fecha_efectiva': manana.toIso8601String(),
      }),
      'ultima_consulta_api': consultaReciente.millisecondsSinceEpoch,
    });

    await tester.pumpWidget(const CuantoesApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Cuantoes'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.textContaining('1 USD = Bs.').first);
    await tester.pumpAndSettle();
    expect(find.text('Tasa oficial BCV'), findsOneWidget);
    expect(find.textContaining('USD'), findsWidgets);
    expect(find.textContaining('EUR'), findsWidgets);
    expect(find.text('1 = Bs. 72,5'), findsOneWidget);
    expect(find.text('1 = Bs. 80'), findsOneWidget);
    expect(find.text('1 = Bs. 172,5'), findsNothing);
    expect(find.text('1 = Bs. 180'), findsNothing);
  });

  testWidgets('App muestra USDT', (WidgetTester tester) async {
    await setUpViewport(tester);

    final manana = DateTime.now().add(const Duration(days: 1));
    final mananaSinHora = DateTime(manana.year, manana.month, manana.day);

    SharedPreferences.setMockInitialValues({
      cacheKey(mananaSinHora): jsonEncode({
        'usd': 72.5,
        'eur': 80.0,
        'usdt': 0,
        'fecha': mananaSinHora.toIso8601String(),
        'origen': 'api',
        'fecha_efectiva': mananaSinHora.toIso8601String(),
      }),
    });

    await tester.pumpWidget(const CuantoesApp());
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('USDT · P2P'), findsOneWidget);
  });

  testWidgets('App maneja error de red', (WidgetTester tester) async {
    await setUpViewport(tester);

    await tester.pumpWidget(const CuantoesApp());
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Cuantoes'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

DateTime _diaHabilAnterior(DateTime fecha) {
  var anterior = DateTime(fecha.year, fecha.month, fecha.day - 1);
  while (anterior.weekday == DateTime.saturday ||
      anterior.weekday == DateTime.sunday ||
      esFeriadoBancario(anterior)) {
    anterior = DateTime(anterior.year, anterior.month, anterior.day - 1);
  }
  return anterior;
}
