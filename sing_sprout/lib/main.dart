import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_state.dart';
import 'shared/providers/audio_provider.dart';
import 'shared/providers/connectivity_provider.dart';
import 'core/routes/app_router.dart';
import 'shared/services/update_service.dart';
import 'shared/widgets/update_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏，适配手机
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 沉浸式状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const SingSproutApp(),
    ),
  );

  // 启动后静默检查更新
  _checkForUpdate();
}

Future<void> _checkForUpdate() async {
  // 延迟 3 秒，等首页渲染完毕
  await Future.delayed(const Duration(seconds: 3));

  final info = await UpdateService().checkForUpdate();
  if (info == null) return;

  // 需要 root navigator context，通过全局 key 获取
  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null) return;

  UpdateDialog.show(context, info);
}
