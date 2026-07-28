import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_config.dart';

/// API service — used only during online sharing; offline composition does not depend on it.
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _client = http.Client();
  String get _baseUrl => AppConfig.apiBaseUrl;

  /// Generate a share link after audio has been uploaded to OSS.
  /// [audioOssKey] is the OSS object key returned by OSSUploadService.
  Future<Map<String, dynamic>?> generateShareLink({
    required String cardId,
    required String deviceId,
    required String audioOssKey,
    String? coverOssKey,
    String? textContent,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/share/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'card_id': cardId,
              'device_id': deviceId,
              'audio_oss_key': audioOssKey,
              'cover_oss_key': coverOssKey,
              'text_content': textContent,
            }),
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Check for new parent replies that haven't been synced yet.
  Future<List<Map<String, dynamic>>> checkReplies(String deviceId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/messages/replies?device_id=$deviceId'))
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['replies'] as List);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
