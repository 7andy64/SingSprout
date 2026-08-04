import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'shared/providers/app_state.dart';
import 'shared/providers/audio_provider.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/economy_provider.dart';
import 'core/routes/app_router.dart';
import 'shared/services/update_service.dart';
import 'shared/services/encryption_service.dart';
import 'shared/services/file_storage_service.dart';
import 'shared/widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 全局错误捕获，防止 Web 端白屏 ──
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
  };

  // Web 端跳过移动端专属配置
  if (!kIsWeb) {
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
  }

  // ── 初始化本地存储服务 ──
  try {
    await _initServices();
  } catch (e) {
    debugPrint('[main] 关键服务初始化失败: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('应用初始化失败',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
                  const SizedBox(height: 8),
                  const Text('请重启应用，如问题持续请重新安装',
                      style: TextStyle(color: Colors.grey),),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      // 简单重启：退出 app 让用户手动重开
                      if (!kIsWeb) {
                        SystemNavigator.pop();
                      }
                    },
                    child: const Text('退出应用'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => EconomyProvider()),
      ],
      child: const SingSproutApp(),
    ),
  );

  // 启动后静默检查更新（仅移动端）
  if (!kIsWeb) {
    _checkForUpdate();
  }
}

/// 初始化加密、文件存储等基础服务。
/// 初始化失败会直接向上抛出，由 [main()] 统一处理。
Future<void> _initServices() async {
  // 1. 文件存储（创建目录结构，Web 端跳过）
  await FileStorageService().initialize();

  // 2. 加密服务（从安全存储读取/生成 AES 密钥）
  final fingerprint = await _getDeviceFingerprint();
  await EncryptionService().initialize(fingerprint);

  // 注意：DatabaseService 延迟初始化，首次调用 repository 时自动创建
}

/// 获取设备唯一标识作为加密种子。
/// Web 端跳过 FlutterSecureStorage，直接生成。
Future<String> _getDeviceFingerprint() async {
  if (kIsWeb) {
    return 'singsprout_web_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  }

  try {
    const storage = FlutterSecureStorage();
    const key = 'singsprout_device_id';

    var id = await storage.read(key: key);
    if (id == null || id.isEmpty) {
      // 生成设备指纹
      final parts = <String>[
        'mobile',
        DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      ];
      id = parts.join('|');
      await storage.write(key: key, value: id);
    }
    return id;
  } catch (_) {
    // 安全存储不可用时使用临时指纹（每次启动可能不同，仅降级兼容）
    return 'singsprout_device_temp_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  }
}

Future<void> _checkForUpdate() async {
  // 等待首帧渲染完成后检查更新
  await WidgetsBinding.instance.endOfFrame;
  await Future.delayed(const Duration(milliseconds: 500));

  final info = await UpdateService().checkForUpdate();
  if (info == null) return;

  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  UpdateDialog.show(context, info);
}
