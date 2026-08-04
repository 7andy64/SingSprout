import 'package:package_info_plus/package_info_plus.dart';

/// 应用环境配置
class AppConfig {
  AppConfig._();

  static PackageInfo? _packageInfo;

  static const String appName = '声芽';
  static const String appNameEn = 'SingSprout';

  /// 运行时版本号（从 APK 元数据读取，自动与 pubspec.yaml 同步，不会出现不一致）
  static String get version => _packageInfo?.version ?? '1.0.0';
  static String get buildNumber => _packageInfo?.buildNumber ?? '10';

  /// 初始化：读取包信息（main.dart 中调用一次）
  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  // 功能开关（MVP 最小闭环已包含：录音编曲 + 守护动物聊天 + 节奏游戏 + 金松果经济）
  static const bool enableGuardianChat = true;    // P0: 守护动物 AI 聊天
  static const bool enableMoodRadio = true;       // P1: 心情收音机
  static const bool enableFieldSoundLab = true;   // P1: 田野声音实验室
  static const bool enableRhythmTribe = true;     // P0: 节奏部落

  // 隐私与安全
  static const bool localEncryptionEnabled = true;
  static const bool dataCollectionDisabled = true;
  static const String privacyPolicyUrl = 'https://singsprout.app/privacy';

  // API 配置
  static const String apiBaseUrl = 'https://api.singsprout.app/v1';
  static const int apiTimeoutSeconds = 30;

  // 下载加速镜像（GitHub 在国内慢，自动加前缀）
  static const List<String> downloadMirrors = [
    '', // 先尝试直连
    'https://ghproxy.com/',
    'https://gh.con.sh/',
  ];

  // 音频参数
  static const int maxRecordingDurationSec = 30;
  static const int hummingMinDurationSec = 3;
  static const int generatedMusicMaxDurationSec = 60;

  // 用户年龄范围
  static const int userAgeMin = 8;
  static const int userAgeMax = 13;

  // 设备分级：≥2GB RAM 启用端侧 AI 模型 (CREPE TFLite)
  static const int highEndDeviceRamMB = 2048;
}
