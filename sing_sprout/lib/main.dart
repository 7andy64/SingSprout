import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_state.dart';
import 'shared/providers/audio_provider.dart';
import 'shared/providers/connectivity_provider.dart';
import 'core/routes/app_router.dart';
import 'shared/services/update_service.dart';
import 'shared/services/encryption_service.dart';
import 'shared/services/file_storage_service.dart';
import 'shared/widgets/update_dialog.dart';

void main() async {
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

  // ── 初始化本地存储服务 ──
  await _initServices();

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

/// 初始化加密、文件存储等基础服务。
Future<void> _initServices() async {
  // 1. 文件存储（创建目录结构）
  await FileStorageService().initialize();

  // 2. 加密服务（从安全存储读取/生成 AES 密钥）
  final fingerprint = await _getDeviceFingerprint();
  await EncryptionService().initialize(fingerprint);

  // 注意：DatabaseService 延迟初始化，首次调用 repository 时自动创建
}

/// 获取设备唯一标识作为加密种子。
Future<String> _getDeviceFingerprint() async {
  try {
    const storage = FlutterSecureStorage();
    const key = 'singsprout_device_id';

    var id = await storage.read(key: key);
    if (id == null || id.isEmpty) {
      // 使用多种特征生成设备指纹
      final parts = <String>[
        Platform.operatingSystem,
        Platform.operatingSystemVersion,
        DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      ];
      id = parts.join('|');
      await storage.write(key: key, value: id);
    }
    return id;
  } catch (_) {
    return 'singsprout_device_fallback';
  }
}

Future<void> _checkForUpdate() async {
  await Future.delayed(const Duration(seconds: 3));

  final info = await UpdateService().checkForUpdate();
  if (info == null) return;

  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null) return;

  UpdateDialog.show(context, info);
}
