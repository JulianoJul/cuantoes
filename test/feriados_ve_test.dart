import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  setUp(() => setFeriadosGoogle({}));

  test('reconoce los feriados fijos por mes y día', () {
    final feriados = [
      DateTime(2026, 1, 1),
      DateTime(2026, 4, 19),
      DateTime(2026, 5, 1),
      DateTime(2026, 6, 24),
      DateTime(2026, 7, 5),
      DateTime(2026, 10, 24),
      DateTime(2026, 12, 25),
      DateTime(2026, 12, 31),
    ];

    for (final feriado in feriados) {
      expect(esFeriadoBancario(feriado), isTrue);
    }

    expect(esFeriadoBancario(DateTime(2026, 1, 19)), isFalse);
    expect(esFeriadoBancario(DateTime(2026, 4, 1)), isFalse);
  });

  test('compara los feriados móviles solo por fecha', () {
    expect(esFeriadoBancario(DateTime(2026, 2, 16, 23, 59)), isTrue);
    expect(esFeriadoBancario(DateTime(2026, 2, 17, 12, 30)), isTrue);
    expect(esFeriadoBancario(DateTime(2026, 4, 2, 8, 15)), isTrue);
    expect(esFeriadoBancario(DateTime(2026, 4, 3, 18, 45)), isTrue);
  });

  test('salta fines de semana y feriados y devuelve una fecha normalizada', () {
    expect(proximoDiaHabil(DateTime(2026, 5, 1, 23, 59)), DateTime(2026, 5, 4));
    expect(proximoDiaHabil(DateTime(2026, 4, 2, 23, 59)), DateTime(2026, 4, 6));
  });

  test('calcula la fecha efectiva usando el corte de las 14:00', () {
    expect(
      calcularFechaEfectiva(DateTime(2026, 4, 1, 13, 59)),
      DateTime(2026, 4, 1),
    );
    expect(
      calcularFechaEfectiva(DateTime(2026, 4, 1, 14)),
      DateTime(2026, 4, 6),
    );
  });
}
