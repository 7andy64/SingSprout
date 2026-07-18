import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_config.dart';

/// API 服务 — 仅在线分享时使用，离线创作不依赖
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _client = http.Client();
  final _baseUrl = AppConfig.apiBaseUrl;

  /// 生成分享链接
  Future<String?> generateShareLink({
    required String cardId,
    required String audioUrl,
    String? coverUrl,
    String? textContent,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/share/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'card_id': cardId,
              'audio_url': audioUrl,
              'cover_url': coverUrl,
              'text_content': textContent,
            }),
          )
          .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['share_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 检查回信
  Future<List<Map<String, dynamic>>> checkReplies(String deviceId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/messages/replies?device_id=$deviceId'),
          )
          .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['replies'] as List);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 上传音频到 OSS（用于生成分享链接）
  Future<String?> uploadAudio(String filePath) async {
    // TODO: 实现 OSS 直传
    return null;
  }

  void dispose() {
    _client.close();
  }
}
