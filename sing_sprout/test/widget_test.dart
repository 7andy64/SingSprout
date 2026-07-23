import 'package:flutter_test/flutter_test.dart';

import 'package:sing_sprout/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SingSproutApp());
    await tester.pumpAndSettle();
  });
}
