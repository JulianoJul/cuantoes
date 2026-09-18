import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/services/tasa_repository.dart';
import 'package:cuantoes/viewmodels/conversor_viewmodel.dart';

class _FakeTasaRepository extends TasaRepository {
  TasaBcv? historica;
  TasaBcv? anterior;
  TasaBcv? actual;
  bool siguienteDisponible = false;
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
  Future<bool> existeTasaSiguiente() async => siguienteDisponible;
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
}
