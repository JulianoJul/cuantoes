import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/main.dart';
import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/services/tasa_repository.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

class _ScreenRepository extends TasaRepository {
  final TasaBcv _actual = TasaBcv(
    usd: 100,
    eur: 110,
    usdt: 0,
    fecha: DateTime(2026, 9, 25),
    origen: 'test',
    fechaEfectiva: DateTime(2026, 9, 25),
  );

  @override
  Future<TasaBcv> obtenerTasa() async => _actual;

  @override
  Future<TasaBcv> refrescarTasa() async => _actual;

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async => _actual;

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async => null;

  @override
  Future<TasaBcv?> obtenerTasaSiguiente() async => null;
}

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

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pump();
    await tester.tap(find.textContaining('1 USD = Bs.').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
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
    expect(find.textContaining('Solicitada $fecha'), findsOneWidget);
  });

  testWidgets('la pantalla puede desplazarse con teclado en 360x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
