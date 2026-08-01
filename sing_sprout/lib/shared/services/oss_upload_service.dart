import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_config.dart';

/// OSS direct upload using STS temporary credentials.
///
/// App requests STS credentials from backend, then uploads directly to OSS.
/// No AccessKey/SecretKey is ever stored on device.
class OSSUploadService {
  static final OSSUploadService _instance = OSSUploadService._();
  factory OSSUploadService() => _instance;
  OSSUploadService._();

  final _client = http.Client();
  String? _cachedDeviceId;

  void setDeviceId(String deviceId) {
    _cachedDeviceId = deviceId;
  }

  /// Upload a file to OSS. Returns the OSS object key on success.
  /// [deviceId] overrides the cached value; falls back to internal cache.
  Future<String?> upload({
    required String filePath,
    required String cardId,
    String? deviceId,
  }) async {
    final dId = deviceId ?? _cachedDeviceId;
    if (dId == null) {
      debugPrint('[OSSUpload] deviceId not set');
      return null;
    }

    try {
      // 1. Request STS credentials from backend
      final stsResp = await _client
          .get(Uri.parse(
              '${AppConfig.apiBaseUrl}/storage/sts?device_id=$dId',),)
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (stsResp.statusCode != 200) {
        debugPrint('[OSSUpload] STS request failed: ${stsResp.statusCode}');
        return null;
      }

      final sts = jsonDecode(stsResp.body) as Map<String, dynamic>;
      final accessKeyId = sts['access_key_id'] as String;
      final accessKeySecret = sts['access_key_secret'] as String;
      final securityToken = sts['security_token'] as String;
      final bucket = sts['bucket'] as String;
      final endpoint = sts['endpoint'] as String;
      final uploadPrefix = sts['upload_prefix'] as String;

      // 2. Upload file to OSS
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final ext = filePath.split('.').last;
      final objectKey = '$uploadPrefix${cardId}_${_nonce()}.$ext';

      final putResp = await _client
          .put(
            Uri.parse('https://$bucket.$endpoint/$objectKey'),
            headers: _ossHeaders(accessKeyId, accessKeySecret, securityToken,
                bucket, endpoint, objectKey,),
            body: fileBytes,
          )
          .timeout(const Duration(seconds: 60));

      if (putResp.statusCode == 200) {
        debugPrint('[OSSUpload] uploaded: $objectKey');
        return objectKey;
      }

      debugPrint('[OSSUpload] upload failed: ${putResp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[OSSUpload] error: $e');
      return null;
    }
  }

  Map<String, String> _ossHeaders(
    String accessKeyId,
    String accessKeySecret,
    String securityToken,
    String bucket,
    String endpoint,
    String objectKey,
  ) {
    final date = _rfc1123Date();
    final contentType = _contentTypeFor(objectKey);

    final stringToSign = [
      'PUT',
      '',
      contentType,
      date,
      'x-oss-security-token:$securityToken',
      '/$bucket/$objectKey',
    ].join('\n');

    final signature = _hmacSha1Base64(accessKeySecret, stringToSign);

    return {
      'Content-Type': contentType,
      'Date': date,
      'x-oss-security-token': securityToken,
      'Authorization': 'OSS $accessKeyId:$signature',
    };
  }

  void dispose() {
    _client.close();
  }

  String _contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _nonce() => (Random().nextInt(99999) + 10000).toString();
  String _rfc1123Date() => DateTime.now().toUtc().toIso8601String();
}

String _hmacSha1Base64(String key, String data) {
  final hmac = Hmac(sha1, utf8.encode(key));
  final digest = hmac.convert(utf8.encode(data));
  return base64.encode(digest.bytes);
}
