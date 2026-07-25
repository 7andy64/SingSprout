import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'shared/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';

class SingSproutApp extends StatelessWidget {
  const SingSproutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp.router(
          title: '声芽 SingSprout',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.router,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final rawScale = mediaQuery.textScaler.scale(1.0);
            final clampedScale = rawScale.clamp(1.0, 1.3);
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(clampedScale)),
              child: child!,
            );
          },
        );
      },
    );
  }
}
