import 'package:flutter_test/flutter_test.dart';

import 'package:kasirgo/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KasirGoApp());
    await tester.pumpAndSettle();

    expect(find.text('KasirGo'), findsOneWidget);
  });
}