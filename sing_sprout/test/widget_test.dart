import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import 'package:sing_sprout/app.dart';
import 'package:sing_sprout/shared/providers/app_state.dart';
import 'package:sing_sprout/shared/providers/audio_provider.dart';
import 'package:sing_sprout/shared/providers/notification_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => AudioProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const SingSproutApp(),
      ),
    );
    // Single pump to verify app instantiates without crashing.
    // Don't pumpAndSettle — the app has continuous animations.
    await tester.pump();
  });
}
