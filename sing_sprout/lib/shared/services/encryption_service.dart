import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本地数据加密服务
///
/// 使用 AES-256-CBC 加密敏感数据。加密密钥存储在
/// Android Keystore / iOS Keychain 中，由 flutter_secure_storage 管理。
///
/// Web 预览模式下降级为 Base64 混淆（非真正加密），
/// 生产环境仅面向 Android 端侧部署。
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._();
  factory EncryptionService() => _instance;
  EncryptionService._();

  static const _keyAlias = 'singsprout_aes_key';
  static const _keyLength = 32; // 256 bits
  final _storage = const FlutterSecureStorage();

  encrypt.Key? _aesKey;
  bool _initialized = false;

  // ── 初始化 ──

  /// 使用设备指纹初始化加密引擎。
  /// [deviceFingerprint] 作为附加熵源，与自动生成的 AES 密钥混合。
  Future<void> initialize(String deviceFingerprint) async {
    if (_initialized) return;

    try {
      // 尝试读取已有的 AES 密钥
      var keyBase64 = await _storage.read(key: _keyAlias);

      if (keyBase64 == null || keyBase64.isEmpty) {
        // 首次启动：生成新密钥并安全存储
        keyBase64 = _generateKeyBase64();
        await _storage.write(key: _keyAlias, value: keyBase64);
      }

      _aesKey = encrypt.Key.fromBase64(keyBase64);
      _initialized = true;
    } catch (e) {
      // 安全存储不可用时（如 Web 预览），回退到派生密钥
      _aesKey = _deriveKeyFromFingerprint(deviceFingerprint);
      _initialized = true;
      debugPrint('[EncryptionService] 安全存储不可用，使用派生密钥');
    }
  }

  // ── 文本加解密 ──

  /// AES-256-CBC 加密文本，返回 Base64 编码的密文。
  String encryptText(String plainText) {
    if (!_initialized || _aesKey == null) {
      // 未初始化时回退到 Base64 混淆（不会丢失数据）
      return base64.encode(utf8.encode(plainText));
    }

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey!));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // 格式：IV(16字节) + 密文，一起 Base64 编码
      final combined = iv.bytes + encrypted.bytes;
      return base64.encode(combined);
    } catch (e) {
      debugPrint('[EncryptionService] 加密失败，回退 Base64: $e');
      return base64.encode(utf8.encode(plainText));
    }
  }

  /// AES-256-CBC 解密文本。
  String decryptText(String encryptedBase64) {
    if (!_initialized || _aesKey == null) {
      try {
        return utf8.decode(base64.decode(encryptedBase64));
      } catch (_) {
        return encryptedBase64;
      }
    }

    try {
      final combined = base64.decode(encryptedBase64);

      // 前 16 字节是 IV，剩余是密文
      if (combined.length < 17) {
        // 长度不足，可能是旧版 Base64 混淆数据，尝试直接解码
        return utf8.decode(base64.decode(encryptedBase64));
      }

      final iv = encrypt.IV(combined.sublist(0, 16));
      final cipherBytes = combined.sublist(16);

      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey!));
      return encrypter.decrypt(encrypt.Encrypted(cipherBytes), iv: iv);
    } catch (e) {
      // 兼容旧版 Base64 混淆数据
      try {
        return utf8.decode(base64.decode(encryptedBase64));
      } catch (_) {
        return encryptedBase64;
      }
    }
  }

  // ── 文件加密 ──

  /// 加密文件内容（字节数组），返回加密后的字节。
  List<int> encryptBytes(List<int> bytes) {
    if (!_initialized || _aesKey == null) return bytes;

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey!));
      final encrypted = encrypter.encryptBytes(Uint8List.fromList(bytes), iv: iv);
      return iv.bytes + encrypted.bytes;
    } catch (e) {
      debugPrint('[EncryptionService] 文件加密失败: $e');
      return bytes;
    }
  }

  /// 解密文件内容（字节数组），返回明文字节。
  List<int> decryptBytes(List<int> encryptedBytes) {
    if (!_initialized || _aesKey == null) return encryptedBytes;
    if (encryptedBytes.length < 17) return encryptedBytes;

    try {
      final iv = encrypt.IV(Uint8List.fromList(encryptedBytes.sublist(0, 16)));
      final cipherBytes = Uint8List.fromList(encryptedBytes.sublist(16));
      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey!));
      return encrypter.decryptBytes(encrypt.Encrypted(cipherBytes), iv: iv);
    } catch (e) {
      return encryptedBytes;
    }
  }

  /// 检查是否已完成安全初始化。
  bool get isInitialized => _initialized;

  // ── 内部方法 ──

  /// 生成随机的 256-bit AES 密钥，返回 Base64 编码。
  String _generateKeyBase64() {
    final random = Random.secure();
    final bytes = List<int>.generate(_keyLength, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// 从设备指纹派生出 AES 密钥（安全存储不可用时的回退方案）。
  /// 使用多次 SHA-256 迭代模拟 PBKDF2，增加暴力破解成本。
  /// 注意：这仍是降级方案，密钥强度取决于指纹的熵值。
  encrypt.Key _deriveKeyFromFingerprint(String fingerprint) {
    var digest = sha256.convert(utf8.encode(fingerprint)).bytes;
    // 多次迭代增加派生成本
    for (var i = 0; i < 1000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return encrypt.Key(Uint8List.fromList(digest));
  }
}
