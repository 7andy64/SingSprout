import 'dart:convert';
import 'dart:math';

/// 本地数据加密服务 stub（web 预览模式）
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._();
  factory EncryptionService() => _instance;
  EncryptionService._();

  String _key = '';

  Future<void> initialize(String deviceFingerprint) async {
    _key = deviceFingerprint;
  }

  String encryptText(String plainText) {
    final bytes = utf8.encode(plainText);
    return base64.encode(bytes);
  }

  String decryptText(String encryptedBase64) {
    final bytes = base64.decode(encryptedBase64);
    return utf8.decode(bytes);
  }
}
