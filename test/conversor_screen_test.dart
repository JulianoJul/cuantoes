import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('el botón de calendario permite seleccionar un fin de semana', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('selected-rate-date-button')));
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
    expect(find.text(fecha), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('selected-rate-date-label')))
          .data,
      fecha,
    );
  });

  testWidgets('Ajustes abre desde su botón secundario', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pump();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias'), findsOneWidget);
    expect(find.text('Conversor compacto (widget)'), findsOneWidget);
    expect(find.text('Valores predefinidos'), findsOneWidget);
  });

  testWidgets('intercambio tiene una fila propia y cambia la dirección', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();

    final swap = find.byKey(const Key('swap-direction-button'));
    final dropdown = find.byType(DropdownButton<String>).first;
    final selector = find.byKey(const Key('currency-pair-selector'));
    final ves = find.byKey(const Key('ves-pair-label'));
    expect(swap, findsOneWidget);
    expect(
      tester.getTopLeft(swap).dy,
      greaterThan(tester.getBottomLeft(dropdown).dy),
    );
    expect(
      tester.getSize(selector).width,
      greaterThan(tester.getSize(ves).width),
    );
    expect(
      tester.getTopLeft(find.text('Monto en USD (\$)')).dy -
          tester.getBottomLeft(swap).dy,
      greaterThanOrEqualTo(12),
    );
    expect(find.text('Intercambiar VES y USD'), findsOneWidget);

    await tester.tap(swap);
    await tester.pump();
    expect(find.text('Monto en VES (Bs.)'), findsOneWidget);
    expect(find.text('Resultado en USD (\$)'), findsOneWidget);
  });

  testWidgets('el contenido de inicio queda centrado verticalmente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();

    final content = find.byKey(const Key('home-content'));
    final topSpace = tester.getTopLeft(content).dy;
    final bottomSpace =
        tester.view.physicalSize.height - tester.getBottomRight(content).dy;
    expect((topSpace - bottomSpace).abs(), lessThan(24));
  });

  testWidgets('permite configurar cuatro valores del widget', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valores predefinidos'));
    await tester.pumpAndSettle();

    const values = ['1', '3', '5', '15'];
    for (var index = 0; index < values.length; index++) {
      await tester.enterText(
        find.byKey(Key('widget-preset-$index')),
        values[index],
      );
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1  ·  3  ·  5  ·  15'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('setting_widget_preset_amounts'), values);
  });

  testWidgets('la pantalla puede desplazarse con teclado en 360x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('conversion-panel'));
    final sizeSinTeclado = tester.getSize(panel);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Conversor'), findsNothing);
    expect(tester.getSize(panel), sizeSinTeclado);
    expect(find.byKey(const Key('selected-rate-date-button')), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    expect(find.text('Monto en USD (\$)'), findsOneWidget);
    expect(find.text('Resultado en VES (Bs.)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resultado y portapapeles conservan dos decimales', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2,5');
    await tester.pump();

    expect(find.text('250,00'), findsOneWidget);
    await tester.tap(find.byTooltip('Copiar resultado'));
    await tester.pump();

    expect(clipboardText, '250,00');
  });

  testWidgets('tocar una zona vacía cierra el teclado', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CuantoesApp(repository: _ScreenRepository()));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField).first);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
  });
}
