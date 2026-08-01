import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'shared/providers/app_state.dart';
import 'shared/providers/audio_provider.dart';
import 'shared/providers/notification_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/services/audio_service.dart';
import 'shared/services/outbox_queue_service.dart';
import 'shared/services/pitch_detection_service.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';

class SingSproutApp extends StatefulWidget {
  const SingSproutApp({super.key});

  @override
  State<SingSproutApp> createState() => _SingSproutAppState();
}

class _SingSproutAppState extends State<SingSproutApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLocalData();
      context.read<NotificationProvider>().loadInitialCount();
    });
    PitchDetectionService().initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleInterruption();
    }
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  void _handleInterruption() {
    final audioProvider = context.read<AudioProvider>();
    if (!audioProvider.isRecording) return;

    debugPrint('[Lifecycle] 应用被中断，正在录制中，自动保存片段...');
    AudioService().saveOnInterrupt().then((path) {
      if (path != null) {
        audioProvider.recordingInterrupted(path);
      } else {
        audioProvider.stopRecording();
      }
    });
  }

  void _handleResume() {
    final audioProvider = context.read<AudioProvider>();
    if (audioProvider.hasSavedFragment) {
      debugPrint('[Lifecycle] 应用恢复，存在已保存的录音片段');
    }

    OutboxQueueService().processQueue(deviceId: 'default').then((_) {
      if (mounted) {
        context.read<NotificationProvider>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: '声芽 SingSprout',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.mode,
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
      },
    );
  }
}
