import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/models/resultado_tasa.dart';
import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/models/widget_snapshot.dart';

void main() {
  test('snapshot comparte USD/EUR formateados y metadatos BCV', () {
    final resultado = ResultadoTasa(
      tasa: TasaBcv(
        usd: 855.6625,
        eur: 972.648677,
        usdt: 0,
        fecha: DateTime.utc(2026, 9, 27),
        origen: 'dolarapi',
        fechaEfectiva: DateTime(2026, 9, 25),
      ),
      modoObtencion: ModoObtencionTasa.red,
      ultimaValidacionExitosaUtc: DateTime.utc(2026, 9, 27, 17),
      ultimoIntentoUtc: DateTime.utc(2026, 9, 27, 17),
      frescura: EstadoFrescuraTasa.vigente,
    );

    final snapshot = WidgetSnapshot.fromResultadoTasa(resultado);

    expect(snapshot.usd, '855,6625');
    expect(snapshot.eur, '972,6487');
    expect(snapshot.effectiveDate, '25/09/2026');
    expect(snapshot.validatedAt, 'Validada 27/09 13:00');
    expect(snapshot.source, 'DolarAPI');
    expect(snapshot.status, contains('Validada'));
  });

  test('snapshot advierte si conserva una tasa offline', () {
    final resultado = ResultadoTasa(
      tasa: TasaBcv(
        usd: 100,
        eur: 110,
        usdt: 0,
        fecha: DateTime(2026, 9, 25),
        origen: 'bcv_today',
        fechaEfectiva: DateTime(2026, 9, 25),
      ),
      modoObtencion: ModoObtencionTasa.cache,
      ultimaValidacionExitosaUtc: null,
      ultimoIntentoUtc: null,
      frescura: EstadoFrescuraTasa.antigua,
      errorActualizacion: 'offline',
    );

    final snapshot = WidgetSnapshot.fromResultadoTasa(resultado);
    expect(snapshot.status, contains('No se pudo actualizar'));
    expect(snapshot.status, contains('tasa antigua'));
    expect(snapshot.validatedAt, 'Validación desconocida');
  });
}
