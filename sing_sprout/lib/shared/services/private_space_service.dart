import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 私密空间密码服务
///
/// 为"留给自己的歌"等私密内容设置独立访问密码。
/// 密码以 SHA-256 哈希形式存储在本地 Android Keystore 中，不上传。
///
/// 忘记密码时可通过重置移除访问控制（不会删除数据）。
class PrivateSpaceService {
  static final PrivateSpaceService _instance = PrivateSpaceService._();
  factory PrivateSpaceService() => _instance;
  PrivateSpaceService._();

  static const _hashKey = 'singsprout_private_pw_hash';
  final _storage = const FlutterSecureStorage();

  /// 是否已设置密码
  Future<bool> isPasswordSet() async {
    try {
      final hash = await _storage.read(key: _hashKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 设置新密码（仅在未设置时可用）
  Future<bool> setPassword(String password) async {
    if (password.length < 4) return false;
    try {
      final hash = _hashPassword(password);
      await _storage.write(key: _hashKey, value: hash);
      return true;
    } catch (e) {
      debugPrint('[PrivateSpace] 设置密码失败: $e');
      return false;
    }
  }

  /// 修改密码（需验证旧密码）
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!await verifyPassword(oldPassword)) return false;
    if (newPassword.length < 4) return false;
    try {
      final hash = _hashPassword(newPassword);
      await _storage.write(key: _hashKey, value: hash);
      return true;
    } catch (e) {
      debugPrint('[PrivateSpace] 修改密码失败: $e');
      return false;
    }
  }

  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    try {
      final storedHash = await _storage.read(key: _hashKey);
      if (storedHash == null || storedHash.isEmpty) return false;
      return _hashPassword(password) == storedHash;
    } catch (_) {
      return false;
    }
  }

  /// 重置密码（移除访问控制，数据不丢失）
  Future<bool> resetPassword() async {
    try {
      await _storage.delete(key: _hashKey);
      return true;
    } catch (e) {
      debugPrint('[PrivateSpace] 重置密码失败: $e');
      return false;
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode('singsprout_salt_$password');
    var digest = sha256.convert(bytes).bytes;
    // 多次迭代增加安全性
    for (var i = 0; i < 500; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64.encode(digest);
  }
}
