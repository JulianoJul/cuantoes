import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/models/cotizacion_usdt.dart';
import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/services/tasa_repository.dart';
import 'package:cuantoes/utils/feriados_ve.dart';
import 'package:cuantoes/viewmodels/conversor_viewmodel.dart';

class _FakeTasaRepository extends TasaRepository {
  TasaBcv? historica;
  TasaBcv? anterior;
  TasaBcv? actual;
  TasaBcv? siguiente;
  CotizacionUsdt? usdt;
  int obtenerCotizacionUsdtCalls = 0;
  bool refrescoUsdtForzado = false;
  int obtenerTasaCalls = 0;
  int refrescarTasaCalls = 0;
  int obtenerTasaHistoricaCalls = 0;
  final limitesAnteriores = <DateTime>[];

  @override
  Future<TasaBcv> obtenerTasa() async {
    obtenerTasaCalls++;
    return actual!;
  }

  @override
  Future<TasaBcv> refrescarTasa() async {
    refrescarTasaCalls++;
    return actual!;
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    obtenerTasaHistoricaCalls++;
    return historica;
  }

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    limitesAnteriores.add(fechaLimite);
    return anterior;
  }

  @override
  Future<TasaBcv?> obtenerTasaSiguiente() async => siguiente;

  @override
  Future<CotizacionUsdt?> obtenerCotizacionUsdt({bool forzar = false}) async {
    obtenerCotizacionUsdtCalls++;
    refrescoUsdtForzado = forzar;
    return usdt;
  }
}

TasaBcv _tasa({
  required double usd,
  required double eur,
  required DateTime efectiva,
}) {
  return TasaBcv(
    usd: usd,
    eur: eur,
    usdt: 0,
    fecha: efectiva,
    origen: 'test',
    fechaEfectiva: efectiva,
  );
}

DateTime _hoyVenezuela() {
  final ahora = ahoraVenezuela();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'feriados_google_last_sync': DateTime.now().toUtc().toIso8601String(),
    });
  });

  test(
    'keeps a weekend selection and calculates historical variation',
    () async {
      final repository = _FakeTasaRepository()
        ..historica = _tasa(usd: 100, eur: 200, efectiva: DateTime(2026, 9, 4))
        ..anterior = _tasa(usd: 90, eur: 180, efectiva: DateTime(2026, 9, 3));
      final vm = ConversorViewmodel(repository: repository);
      addTearDown(vm.dispose);

      final seleccionada = DateTime(2026, 9, 6);
      await vm.seleccionarFecha(seleccionada);

      expect(vm.fechaSeleccionada, seleccionada);
      expect(vm.fechaEfectivaAplicada, DateTime(2026, 9, 4));
      expect(vm.variacion, closeTo(11.1111, 0.0001));
      expect(repository.obtenerTasaCalls, 0);
      expect(repository.limitesAnteriores, [DateTime(2026, 9, 4)]);
    },
  );

  test(
    'calculates current variation from the previous effective rate',
    () async {
      final repository = _FakeTasaRepository()
        ..actual = _tasa(usd: 100, eur: 200, efectiva: DateTime(2026, 9, 7))
        ..anterior = _tasa(usd: 95, eur: 190, efectiva: DateTime(2026, 9, 4));
      final vm = ConversorViewmodel(repository: repository);
      addTearDown(vm.dispose);

      await vm.cargarTasa();

      expect(vm.variacion, closeTo(5.2631, 0.0001));
      expect(repository.limitesAnteriores, [DateTime(2026, 9, 7)]);
    },
  );

  test('does not replace missing historical data with live data', () async {
    final repository = _FakeTasaRepository();
    final vm = ConversorViewmodel(repository: repository);
    addTearDown(vm.dispose);

    await vm.seleccionarFecha(DateTime(2026, 9, 6));

    expect(vm.fechaSeleccionada, DateTime(2026, 9, 6));
    expect(vm.estado, EstadoTasa.error);
    expect(vm.error, 'Sin datos para esta fecha');
    expect(vm.tasa, isNull);
    expect(repository.obtenerTasaCalls, 0);
  });

  test(
    'refreshes the selected historical date instead of loading live data',
    () async {
      final repository = _FakeTasaRepository()
        ..historica = _tasa(usd: 100, eur: 200, efectiva: DateTime(2026, 9, 4));
      final vm = ConversorViewmodel(repository: repository);
      addTearDown(vm.dispose);

      await vm.seleccionarFecha(DateTime(2026, 9, 6));
      await vm.refrescarTasa();

      expect(repository.refrescarTasaCalls, 0);
      expect(repository.obtenerTasaHistoricaCalls, 2);
      expect(vm.fechaSeleccionada, DateTime(2026, 9, 6));
    },
  );

  test('sin tasa siguiente el calendario solo llega hasta hoy', () async {
    final hoy = _hoyVenezuela();
    final repository = _FakeTasaRepository()
      ..actual = _tasa(usd: 100, eur: 200, efectiva: hoy);
    final vm = ConversorViewmodel(repository: repository);
    addTearDown(vm.dispose);

    await vm.cargarTasa();

    expect(vm.fechaTasaSiguiente, isNull);
    expect(vm.tasaSiguienteDisponible, isFalse);
    expect(vm.fechaMaximaSeleccionable, hoy);
  });

  test('con tasa siguiente el calendario llega hasta esa fecha', () async {
    final hoy = _hoyVenezuela();
    final manana = hoy.add(const Duration(days: 1));
    final repository = _FakeTasaRepository()
      ..actual = _tasa(usd: 100, eur: 200, efectiva: hoy)
      ..siguiente = _tasa(usd: 110, eur: 220, efectiva: manana);
    final vm = ConversorViewmodel(repository: repository);
    addTearDown(vm.dispose);

    await vm.cargarTasa();

    expect(vm.fechaTasaSiguiente, manana);
    expect(vm.tasaSiguienteDisponible, isTrue);
    expect(vm.fechaMaximaSeleccionable, manana);
  });

  test(
    'USDT no contamina tasas BCV y calcula con cotización separada',
    () async {
      final repository = _FakeTasaRepository()
        ..actual = _tasa(usd: 100, eur: 110, efectiva: _hoyVenezuela())
        ..usdt = CotizacionUsdt(
          valor: 120,
          fechaEfectiva: _hoyVenezuela(),
          obtenidaEnUtc: DateTime.now().toUtc(),
          origen: 'p2p-test',
        );
      final vm = ConversorViewmodel(repository: repository);
      addTearDown(vm.dispose);

      await vm.cargarTasa();
      await vm.setMoneda('USDT');
      vm.setEntrada('2');

      expect(vm.tasa?.usdt, 0);
      expect(vm.cotizacionUsdt?.origen, 'p2p-test');
      expect(vm.tasaActual, 120);
      expect(vm.resultado, '240.00');
      expect(repository.obtenerCotizacionUsdtCalls, 1);
    },
  );

  test(
    'una tasa USDT ausente no genera Infinity y limpia el resultado',
    () async {
      final repository = _FakeTasaRepository()
        ..actual = _tasa(usd: 100, eur: 110, efectiva: _hoyVenezuela());
      final vm = ConversorViewmodel(repository: repository);
      addTearDown(vm.dispose);

      await vm.cargarTasa();
      await vm.setMoneda('USDT');
      vm.setEntrada('2');

      expect(vm.errorUsdt, isNotEmpty);
      expect(vm.resultado, isEmpty);
      expect(vm.resultadoPreciso, isEmpty);
    },
  );

  test('entrada numérica incompleta limpia el resultado previo', () async {
    final repository = _FakeTasaRepository()
      ..actual = _tasa(usd: 100, eur: 110, efectiva: _hoyVenezuela());
    final vm = ConversorViewmodel(repository: repository);
    addTearDown(vm.dispose);

    await vm.cargarTasa();
    vm.setEntrada('10');
    expect(vm.resultado, '1000.00');
    vm.setEntrada('10,');
    expect(vm.resultado, isEmpty);
  });

  test('monto OCR en VES establece la dirección inversa', () async {
    final repository = _FakeTasaRepository()
      ..actual = _tasa(usd: 100, eur: 110, efectiva: _hoyVenezuela());
    final vm = ConversorViewmodel(repository: repository);
    addTearDown(vm.dispose);

    await vm.cargarTasa();
    await vm.aplicarMontoEscaneado(monto: '20,00', moneda: 'VES');

    expect(vm.esMonedaAVes, isFalse);
    expect(vm.moneda, 'USD');
    expect(vm.entrada, '20,00');
    expect(vm.resultado, '0.20');
  });
}
