import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'shared/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';

class SingSproutApp extends StatefulWidget {
  const SingSproutApp({super.key});

  @override
  State<SingSproutApp> createState() => _SingSproutAppState();
}

class _SingSproutAppState extends State<SingSproutApp> {
  @override
  void initState() {
    super.initState();
    // 启动时从本地数据库加载用户数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLocalData();
    });
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
