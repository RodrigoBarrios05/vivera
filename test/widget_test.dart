import 'package:flutter_test/flutter_test.dart';

import 'package:vivera/app.dart';

void main() {
  testWidgets('muestra la ayuda de configuración sin Supabase', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MissingConfigApp());

    expect(find.text('Falta configurar Supabase'), findsOneWidget);
  });
}
