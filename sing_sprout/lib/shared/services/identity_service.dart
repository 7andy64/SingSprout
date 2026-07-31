import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// 身份切换密码管理 + 防暴力破解 + 操作日志
///
/// - 密码 AES-128 加密存储在 flutter_secure_storage
/// - 首次使用默认密码 123456，提示用户修改
/// - 连续 5 次验证失败锁定 5 分钟
/// - 所有操作离线完成，不依赖网络
class IdentityService {
  static const _passwordKey = 'identity_switch_password';
  static const _logKey = 'identity_switch_log';
  static const _failCountKey = 'identity_fail_count';
  static const _lockUntilKey = 'identity_lock_until';
  static const _passwordChangedKey = 'identity_pw_changed';
  static const _defaultPassword = '123456';

  static const _maxFails = 5;
  static const _lockMinutes = 5;

  final _storage = const FlutterSecureStorage();

  static final _encrypter = _makeEncrypter();
  static final _iv = enc.IV.fromUtf8('SproutIV!2024!OK');

  static enc.Encrypter _makeEncrypter() {
    final key = enc.Key.fromUtf8('SingSproutID2024');
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  // ═══════════════════════════════════════════════
  //  Init
  // ═══════════════════════════════════════════════

  /// 首次启动时写入默认密码 123456
  Future<void> ensureInitialized() async {
    final existing = await _storage.read(key: _passwordKey);
    if (existing == null || existing.isEmpty) {
      await _setPasswordInternal(_defaultPassword);
      debugPrint('[IdentityService] 已设置默认身份切换密码');
    }
  }

  /// 用户是否修改过默认密码
  Future<bool> get hasChangedPassword async {
    final val = await _storage.read(key: _passwordChangedKey);
    return val == 'true';
  }

  // ═══════════════════════════════════════════════
  //  Lockout
  // ═══════════════════════════════════════════════

  /// 当前是否被锁定
  Future<bool> get isLocked async {
    final lockUntil = await _storage.read(key: _lockUntilKey);
    if (lockUntil == null) return false;
    final until = DateTime.tryParse(lockUntil);
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// 剩余锁定秒数（0 表示未锁定）
  Future<int> get lockRemainingSeconds async {
    final lockUntil = await _storage.read(key: _lockUntilKey);
    if (lockUntil == null) return 0;
    final until = DateTime.tryParse(lockUntil);
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 剩余尝试次数
  Future<int> get remainingAttempts async {
    final count = await _failCount;
    return _maxFails - count;
  }

  Future<int> get _failCount async {
    final val = await _storage.read(key: _failCountKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> _incrementFailCount() async {
    final count = await _failCount + 1;
    await _storage.write(key: _failCountKey, value: count.toString());

    if (count >= _maxFails) {
      final until = DateTime.now().add(const Duration(minutes: _lockMinutes));
      await _storage.write(key: _lockUntilKey, value: until.toIso8601String());
      debugPrint('[IdentityService] 锁定至 $until');
    }
  }

  Future<void> _resetFailCount() async {
    await _storage.write(key: _failCountKey, value: '0');
    await _storage.delete(key: _lockUntilKey);
  }

  // ═══════════════════════════════════════════════
  //  Verify
  // ═══════════════════════════════════════════════

  /// 验证密码。自动处理锁定和失败计数。
  ///
  /// 返回 null=验证通过，否则返回错误消息。
  Future<String?> verifyPassword(String password) async {
    // 检查锁定
    if (await isLocked) {
      final remaining = await lockRemainingSeconds;
      final min = remaining ~/ 60;
      final sec = remaining % 60;
      return '已锁定，请 ${min}分${sec}秒 后重试';
    }

    try {
      final stored = await _storage.read(key: _passwordKey);
      if (stored == null || stored.isEmpty) {
        await _incrementFailCount();
        return '系统未初始化，请重启应用';
      }

      final decrypted = _encrypter.decrypt64(stored, iv: _iv);
      if (decrypted == password) {
        await _resetFailCount();
        return null; // 验证通过
      }

      await _incrementFailCount();
      final remaining = await remainingAttempts;
      if (remaining <= 0) {
        return '密码错误次数过多，已锁定 $_lockMinutes 分钟';
      }
      return '密码错误，请重试（剩余 $remaining 次尝试）';
    } catch (e) {
      debugPrint('[IdentityService] 验证异常: $e');
      await _incrementFailCount();
      return '验证失败，请重试';
    }
  }

  // ═══════════════════════════════════════════════
  //  Change Password
  // ═══════════════════════════════════════════════

  /// 修改密码。返回 null=成功，否则返回错误消息。
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    if (newPassword.length < 4) return '新密码至少4位';

    final verifyResult = await verifyPassword(oldPassword);
    if (verifyResult != null) return verifyResult;

    await _setPasswordInternal(newPassword);
    await _storage.write(key: _passwordChangedKey, value: 'true');
    return null;
  }

  Future<void> _setPasswordInternal(String password) async {
    final encrypted = _encrypter.encrypt(password, iv: _iv);
    await _storage.write(key: _passwordKey, value: encrypted.base64);
  }

  // ═══════════════════════════════════════════════
  //  Log
  // ═══════════════════════════════════════════════

  /// 记录一次身份切换
  Future<void> logSwitch(String fromRole, String toRole) async {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'from': fromRole,
      'to': toRole,
    };

    final raw = await _storage.read(key: _logKey);
    final List<dynamic> logs = raw != null ? jsonDecode(raw) as List<dynamic> : [];
    logs.add(entry);

    if (logs.length > 50) {
      logs.removeRange(0, logs.length - 50);
    }

    await _storage.write(key: _logKey, value: jsonEncode(logs));
  }

  /// 读取切换日志（最新在前）
  Future<List<Map<String, dynamic>>> getLogs() async {
    final raw = await _storage.read(key: _logKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>().reversed.toList();
    } catch (_) {
      return [];
    }
  }
}
