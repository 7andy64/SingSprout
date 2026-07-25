import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_config.dart';

class UpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String latestVersion;
  final String downloadUrl;
  final int fileSize;
  final String sha256;
  final String changelog;

  UpdateInfo({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.latestVersion,
    required this.downloadUrl,
    required this.fileSize,
    required this.sha256,
    required this.changelog,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  static const _installChannel = MethodChannel('com.singsprout.app/install');

  // Gitee 国内快，优先；GitHub 做备用
  static const _apiUrls = [
    'https://gitee.com/api/v5/repos/nanbujiwanfeng/SingSprout/releases/latest',
    'https://api.github.com/repos/nanbujiwanfeng/SingSprout/releases/latest',
  ];

  /// 依次尝试 Gitee → GitHub，谁通用谁
  Future<UpdateInfo?> checkForUpdate() async {
    for (final url in _apiUrls) {
      final info = await _tryApi(url);
      if (info != null) return info;
    }
    return null;
  }

  Future<UpdateInfo?> _tryApi(String apiUrl) async {
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(data);
    } catch (_) {
      return null;
    }
  }

  /// 解析 Release JSON（Gitee 和 GitHub 格式基本一致）
  UpdateInfo? _parseResponse(Map<String, dynamic> data) {
    final tag = (data['tag_name'] as String?) ?? '';
    final latestVersion =
        tag.startsWith('v') ? tag.substring(1) : tag;
    if (latestVersion.isEmpty) return null;

    // 找到 APK
    final assets = (data['assets'] as List?) ?? [];
    Map<String, dynamic>? apkAsset;
    for (final a in assets) {
      final name = (a['name'] as String?) ?? '';
      if (name.endsWith('.apk')) {
        apkAsset = a as Map<String, dynamic>;
        break;
      }
    }
    if (apkAsset == null) return null;

    var downloadUrl =
        apkAsset['browser_download_url'] as String? ?? '';
    if (downloadUrl.isEmpty) return null;

    // GitHub 下载走镜像加速
    if (downloadUrl.contains('github.com')) {
      downloadUrl = 'https://ghproxy.com/$downloadUrl';
    }

    final fileSize = apkAsset['size'] as int? ?? 0;

    final body = (data['body'] as String?) ?? '';
    final forceUpdate = body.contains('[force]');

    final sha256Match = RegExp(
      r'SHA256:\s*([a-f0-9]{64})',
      caseSensitive: false,
    ).firstMatch(body);
    final sha256 = sha256Match?.group(1) ?? '';

    final changelog = body
        .replaceAll(RegExp(r'\[force\]', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'SHA256:\s*[a-f0-9]{64}', caseSensitive: false),
          '',
        )
        .trim();

    if (!_versionGreater(latestVersion, AppConfig.version)) return null;

    return UpdateInfo(
      hasUpdate: true,
      forceUpdate: forceUpdate,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      fileSize: fileSize,
      sha256: sha256,
      changelog: changelog,
    );
  }

  /// 下载 APK，通过 [onProgress] 回调进度 (0.0 ~ 1.0)
  /// 固定文件名，重试时覆盖旧文件
  Future<File> downloadApk(
    String url,
    void Function(double) onProgress,
  ) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw Exception('无法访问外部存储');
    final savePath = '${dir.path}/singsprout_update.apk';

    // 删除旧的部分下载文件
    final oldFile = File(savePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final contentLength = response.contentLength;
      final file = File(savePath);
      final sink = file.openWrite();
      var received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      }

      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// 校验文件 SHA256
  Future<bool> verifySha256(File file, String expectedHash) async {
    if (expectedHash.isEmpty) return true;
    try {
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      return hash == expectedHash;
    } catch (_) {
      return false;
    }
  }

  /// 调起系统安装器
  Future<void> installApk(File file) async {
    await _installChannel.invokeMethod('installApk', {
      'filePath': file.path,
    });
  }

  /// 简单 semver 比较：a > b
  static bool _versionGreater(String a, String b) {
    try {
      final pa = a.split('.').map(int.parse).toList();
      final pb = b.split('.').map(int.parse).toList();
      while (pa.length < 3) { pa.add(0); }
      while (pb.length < 3) { pb.add(0); }
      for (var i = 0; i < 3; i++) {
        if (pa[i] > pb[i]) return true;
        if (pa[i] < pb[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
