import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/screens/rate_date_picker.dart';

void main() {
  test('solo la próxima fecha publicada es seleccionable en el futuro', () {
    final hoy = DateTime(2026, 9, 29);
    final proxima = DateTime(2026, 10, 2);

    expect(esFechaDisponibleTasa(DateTime(2026, 9, 28), hoy, proxima), isTrue);
    expect(esFechaDisponibleTasa(hoy, hoy, proxima), isTrue);
    expect(esFechaDisponibleTasa(DateTime(2026, 9, 30), hoy, proxima), isFalse);
    expect(esFechaDisponibleTasa(DateTime(2026, 10, 1), hoy, proxima), isFalse);
    expect(esFechaDisponibleTasa(proxima, hoy, proxima), isTrue);
    expect(esFechaDisponibleTasa(proxima, hoy, null), isFalse);
  });
}
