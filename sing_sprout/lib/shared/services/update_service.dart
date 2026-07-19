import 'dart:async';
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

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      hasUpdate: json['has_update'] as bool? ?? false,
      forceUpdate: json['force_update'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
    );
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  static const _installChannel = MethodChannel('com.singsprout.app/install');
  final _baseUrl = AppConfig.apiBaseUrl;

  /// 检查是否有新版本
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/updates/check?platform=android&version=${AppConfig.version}',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final info = UpdateInfo.fromJson(data);
        return info.hasUpdate ? info : null;
      }
      return null;
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
    final savePath = '${dir!.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk';

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
}
