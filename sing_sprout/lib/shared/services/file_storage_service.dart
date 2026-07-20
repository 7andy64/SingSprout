import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// 文件存储服务
///
/// 管理应用内的文件目录结构，用于存储音频录音文件、
/// AI 生成的音乐文件和封面图片。
///
/// 目录结构：
/// ```
/// app_documents/
/// ├── recordings/     ← 原始录音文件 (.m4a / .wav)
/// ├── generated/      ← AI 生成的音乐 (.mp3 / .wav)
/// ├── covers/         ← 作品封面图 (.png / .jpg)
/// ├── exports/        ← 待分享的临时文件
/// └── models/         ← 下载的 AI 模型文件（由 UpdateService 管理）
/// ```
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._();
  factory FileStorageService() => _instance;
  FileStorageService._();

  String? _rootPath;
  bool _initialized = false;

  // ── 初始化 ──

  /// 初始化存储目录结构，创建所有必需的子目录。
  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _rootPath = appDir.path;

    // 确保所有子目录存在
    await _ensureDir(recordingsDir);
    await _ensureDir(generatedDir);
    await _ensureDir(coversDir);
    await _ensureDir(exportsDir);

    _initialized = true;
    debugPrint('[FileStorageService] 存储初始化完成: $_rootPath');
  }

  // ── 目录路径 ──

  String get rootPath {
    _ensureInit();
    return _rootPath!;
  }

  String get recordingsDir => p.join(_rootPath!, 'recordings');
  String get generatedDir => p.join(_rootPath!, 'generated');
  String get coversDir => p.join(_rootPath!, 'covers');
  String get exportsDir => p.join(_rootPath!, 'exports');

  // ── 文件操作 ──

  /// 为新的录音文件生成路径。
  /// 格式: recordings/yyyyMMdd_HHmmss_随机数.m4a
  String generateRecordingPath({String extension = 'm4a'}) {
    final timestamp = _timestamp();
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return p.join(recordingsDir, 'rec_${timestamp}_$random.$extension');
  }

  /// 为 AI 生成的音乐文件生成路径。
  /// 格式: generated/yyyyMMdd_HHmmss_风格种子.mp3
  String generateMusicPath({String styleSeed = '', String extension = 'mp3'}) {
    final timestamp = _timestamp();
    final seed = styleSeed.isNotEmpty ? '_$styleSeed' : '';
    return p.join(generatedDir, 'gen_$timestamp$seed.$extension');
  }

  /// 为封面图生成路径。
  /// 格式: covers/yyyyMMdd_HHmmss_随机数.png
  String generateCoverPath({String extension = 'png'}) {
    final timestamp = _timestamp();
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return p.join(coversDir, 'cover_${timestamp}_$random.$extension');
  }

  /// 保存字节数据到文件，返回文件路径。
  Future<String> saveBytes(String path, List<int> bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// 从文件读取字节数据。
  Future<List<int>?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// 删除文件，文件不存在时不报错。
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 检查文件是否存在。
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// 获取文件大小（字节），文件不存在返回 0。
  Future<int> fileSize(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// 计算存储目录总占用空间（字节）。
  Future<int> totalStorageUsed() async {
    _ensureInit();
    var total = 0;
    for (final dir in [recordingsDir, generatedDir, coversDir, exportsDir]) {
      total += await _dirSize(dir);
    }
    return total;
  }

  /// 清理 exports 目录中的所有临时文件。
  Future<void> clearExports() async {
    final dir = Directory(exportsDir);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  // ── 工具方法 ──

  void _ensureInit() {
    if (!_initialized) {
      throw StateError('FileStorageService 尚未初始化，请先调用 initialize()');
    }
  }

  Future<void> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<int> _dirSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
