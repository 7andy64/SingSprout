/// 应用环境配置
class AppConfig {
  AppConfig._();

  static const String appName = '声芽';
  static const String appNameEn = 'SingSprout';
  static const String version = '0.4.0';

  // 功能开关（MVP 阶段仅开启 P0 功能）
  static const bool enableMoodRadio = true;      // P1: 完整心情收音机
  static const bool enableFieldSoundLab = false;  // P1: 田野声音实验室
  static const bool enableRhythmTribe = false;    // P2: 节奏部落

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
}
