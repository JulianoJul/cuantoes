import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/main.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('el calendario permite seleccionar un fin de semana', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CuantoesApp());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    var sabado = hoy;
    while (sabado.weekday != DateTime.saturday) {
      sabado = sabado.subtract(const Duration(days: 1));
    }

    if (sabado.month != hoy.month || sabado.year != hoy.year) {
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
    }

    final dia = find.text('${sabado.day}');
    expect(dia, findsWidgets);
    await tester.tap(dia.last);
    await tester.pump();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pump();

    final fecha =
        '${sabado.day.toString().padLeft(2, '0')}/${sabado.month.toString().padLeft(2, '0')}/${sabado.year}';
    expect(find.text('Sábado - $fecha'), findsOneWidget);
  });
}
