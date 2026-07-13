import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CuantoesApp());
    await tester.pump();

    expect(find.text('Tasa BCV'), findsOneWidget);
  });
}
