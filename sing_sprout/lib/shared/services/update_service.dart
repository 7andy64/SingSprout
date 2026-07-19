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

  static const _apiUrl =
      'https://api.github.com/repos/nanbujiwanfeng/SingSprout/releases/latest';

  /// 检查 GitHub Releases 是否有新版本
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // 解析版本号 (tag_name: "v0.2.0" → "0.2.0")
      final tag = (data['tag_name'] as String?) ?? '';
      final latestVersion =
          tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty) return null;

      // 找到 APK 文件
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

      final downloadUrl =
          apkAsset['browser_download_url'] as String? ?? '';
      if (downloadUrl.isEmpty) return null;

      final fileSize = apkAsset['size'] as int? ?? 0;

      // 解析 Release body
      final body = (data['body'] as String?) ?? '';
      final forceUpdate = body.contains('[force]');

      // 从 body 中提取 SHA256
      final sha256Match = RegExp(r'SHA256:\s*([a-f0-9]{64})',
              caseSensitive: false)
          .firstMatch(body);
      final sha256 = sha256Match?.group(1) ?? '';

      // 去除 [force] 和 SHA256 行后的纯文本 changelog
      final changelog = body
          .replaceAll(RegExp(r'\[force\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'SHA256:\s*[a-f0-9]{64}', caseSensitive: false),
              '')
          .trim();

      // 版本比较
      final hasUpdate = _versionGreater(latestVersion, AppConfig.version);

      if (!hasUpdate) return null;

      return UpdateInfo(
        hasUpdate: true,
        forceUpdate: forceUpdate,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        fileSize: fileSize,
        sha256: sha256,
        changelog: changelog,
      );
    } catch (_) {
      return null;
    }
  }

  /// 下载 APK，通过 [onProgress] 回调进度 (0.0 ~ 1.0)
  Future<File> downloadApk(
    String url,
    void Function(double) onProgress,
  ) async {
    final dir = await getExternalStorageDirectory();
    final savePath =
        '${dir!.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk';

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
