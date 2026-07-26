import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

/// 私密空间密码服务
///
/// 使用 AES-256 加密存储密码（与作品数据共用 EncryptionService 密钥），
/// 本地验证，不上传。忘记密码时可重置，数据不丢失。
class PrivateSpaceService {
  static final PrivateSpaceService _instance = PrivateSpaceService._();
  factory PrivateSpaceService() => _instance;
  PrivateSpaceService._();

  static const _pwKey = 'singsprout_private_pw';
  final _storage = const FlutterSecureStorage();

  /// 是否已设置密码
  Future<bool> isPasswordSet() async {
    try {
      final encrypted = await _storage.read(key: _pwKey);
      return encrypted != null && encrypted.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 设置新密码
  Future<bool> setPassword(String password) async {
    if (password.length < 4) return false;
    try {
      final enc = EncryptionService();
      if (!enc.isInitialized) return false;
      final encrypted = enc.encryptText('pw:$password');
      await _storage.write(key: _pwKey, value: encrypted);
      debugPrint('[PrivateSpace] 密码已设置 (AES)');
      return true;
    } catch (e) {
      debugPrint('[PrivateSpace] 设置密码失败: $e');
      return false;
    }
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!await verifyPassword(oldPassword)) return false;
    return setPassword(newPassword);
  }

  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    try {
      final enc = EncryptionService();
      if (!enc.isInitialized) return false;

      final stored = await _storage.read(key: _pwKey);
      if (stored == null || stored.isEmpty) return false;

      final decrypted = enc.decryptText(stored);
      return decrypted == 'pw:$password';
    } catch (_) {
      return false;
    }
  }

  /// 重置密码（移除访问控制，数据不丢失）
  Future<bool> resetPassword() async {
    try {
      await _storage.delete(key: _pwKey);
      debugPrint('[PrivateSpace] 密码已重置');
      return true;
    } catch (e) {
      debugPrint('[PrivateSpace] 重置密码失败: $e');
      return false;
    }
  }
}
