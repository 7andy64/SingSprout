import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地 JSON 文件存储服务
///
/// 所有创作数据默认本地加密存储（MVP 阶段使用明文 JSON，
/// 后续接入 EncryptionService）。
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._();
  factory LocalStorageService() => _instance;
  LocalStorageService._();

  Future<Directory> get _docsDir async {
    if (kIsWeb) {
      // Web 模式回退 — 不会真正持久化，仅用于调试
      return Directory.systemTemp;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _file(String filename) async {
    final dir = await _docsDir;
    final storageDir = Directory('${dir.path}/singsprout');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return File('${storageDir.path}/$filename');
  }

  /// 读取 JSON 列表，文件不存在时返回空列表
  Future<List<Map<String, dynamic>>> readList(String filename) async {
    try {
      final file = await _file(filename);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = json.decode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[LocalStorage] readList error: $e');
      return [];
    }
  }

  /// 写入 JSON 列表（全量覆盖）
  Future<void> writeList(String filename, List<Map<String, dynamic>> data) async {
    try {
      final file = await _file(filename);
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('[LocalStorage] writeList error: $e');
    }
  }

  /// 读取单个 JSON 对象
  Future<Map<String, dynamic>?> readJson(String filename) async {
    try {
      final file = await _file(filename);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalStorage] readJson error: $e');
      return null;
    }
  }

  /// 写入单个 JSON 对象
  Future<void> writeJson(String filename, Map<String, dynamic> data) async {
    try {
      final file = await _file(filename);
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('[LocalStorage] writeJson error: $e');
    }
  }
}
