import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// 文件存储服务
///
/// 管理应用内的文件目录结构，用于存储音频录音文件、
/// AI 生成的音乐文件和封面图片。
///
/// Web 端此服务为空实现，所有文件操作均返回安全默认值。
///
/// 目录结构（移动端）：
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

  /// 当前是否运行在 Web 平台。
  bool get _isWeb => kIsWeb;

  // ── 初始化 ──

  /// 初始化存储目录结构，创建所有必需的子目录。
  /// Web 端跳过文件系统操作。
  Future<void> initialize() async {
    if (_initialized) return;
    if (_isWeb) {
      _initialized = true;
      debugPrint('[FileStorageService] Web 模式，跳过文件系统初始化');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    _rootPath = appDir.path;

    // 先标记已初始化，否则目录 getter 中的 _ensureInit() 会报错
    _initialized = true;

    // 确保所有子目录存在
    await _ensureDir(recordingsDir);
    await _ensureDir(generatedDir);
    await _ensureDir(coversDir);
    await _ensureDir(exportsDir);
    await _ensureDir(modelsDir);

    debugPrint('[FileStorageService] 存储初始化完成: $_rootPath');
  }

  // ── 目录路径 ──

  String get rootPath {
    _ensureInit();
    if (_isWeb) return '/web_storage';
    return _rootPath!;
  }

  String get recordingsDir {
    _ensureInit();
    return _isWeb ? '/web_storage/recordings' : p.join(_rootPath!, 'recordings');
  }
  String get generatedDir {
    _ensureInit();
    return _isWeb ? '/web_storage/generated' : p.join(_rootPath!, 'generated');
  }
  String get coversDir {
    _ensureInit();
    return _isWeb ? '/web_storage/covers' : p.join(_rootPath!, 'covers');
  }
  String get exportsDir {
    _ensureInit();
    return _isWeb ? '/web_storage/exports' : p.join(_rootPath!, 'exports');
  }
  String get modelsDir {
    _ensureInit();
    return _isWeb ? '/web_storage/models' : p.join(_rootPath!, 'models');
  }

  // ── 文件操作 ──

  /// 为新的录音文件生成路径。
  String generateRecordingPath({String extension = 'm4a'}) {
    return p.join(recordingsDir, 'rec_${_timestamp()}_${_randomSeed()}.$extension');
  }

  /// 为 AI 生成的音乐文件生成路径。
  String generateMusicPath({String styleSeed = '', String extension = 'mp3'}) {
    final seed = styleSeed.isNotEmpty ? '_${_sanitizeFileName(styleSeed)}' : '';
    return p.join(generatedDir, 'gen_${_timestamp()}${seed}_${_randomSeed()}.$extension');
  }

  /// 为封面图生成路径。
  String generateCoverPath({String extension = 'png'}) {
    return p.join(coversDir, 'cover_${_timestamp()}_${_randomSeed()}.$extension');
  }

  /// 保存字节数据到文件，返回文件路径。
  /// Web 端始终返回传入的 path（不实际写入文件系统）。
  Future<String> saveBytes(String path, List<int> bytes) async {
    if (_isWeb) return path;

    final safePath = _validatePath(path);
    final file = File(safePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return safePath;
  }

  /// 从文件读取字节数据。Web 端始终返回 null。
  Future<List<int>?> readBytes(String path) async {
    if (_isWeb) return null;

    final safePath = _validatePath(path);
    final file = File(safePath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// 删除文件。Web 端为空操作。
  Future<void> deleteFile(String path) async {
    if (_isWeb) return;

    final safePath = _validatePath(path);
    final file = File(safePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 检查文件是否存在。Web 端始终返回 false。
  Future<bool> fileExists(String path) async {
    if (_isWeb) return false;

    return File(_validatePath(path)).exists();
  }

  /// 获取文件大小（字节）。Web 端始终返回 0。
  Future<int> fileSize(String path) async {
    if (_isWeb) return 0;

    final safePath = _validatePath(path);
    final file = File(safePath);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// 计算存储目录总占用空间（字节）。Web 端始终返回 0。
  Future<int> totalStorageUsed() async {
    _ensureInit();
    if (_isWeb) return 0;

    var total = 0;
    for (final dir in [recordingsDir, generatedDir, coversDir, exportsDir]) {
      total += await _dirSize(dir);
    }
    return total;
  }

  /// 清理 exports 目录中的所有临时文件。Web 端为空操作。
  Future<void> clearExports() async {
    if (_isWeb) return;

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

  /// 验证路径在应用存储目录内，防止路径遍历攻击。
  String _validatePath(String filePath) {
    if (_isWeb) return filePath;

    final resolved = p.normalize(p.absolute(filePath));
    final root = p.normalize(p.absolute(_rootPath!));

    if (!resolved.startsWith(root + p.separator) && resolved != root) {
      throw ArgumentError('非法路径: $filePath（不允许访问应用目录以外的路径）');
    }
    return resolved;
  }

  Future<void> _ensureDir(String path) async {
    if (_isWeb) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<int> _dirSize(String path) async {
    if (_isWeb) return 0;

    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // 文件可能在迭代期间被删除
          }
        }
      }
    } catch (_) {
      // 目录可能在迭代期间被删除
    }
    return total;
  }

  /// 生成安全的随机文件名后缀，避免基于时间的碰撞。
  String _randomSeed() {
    final rng = Random.secure();
    return rng.nextInt(99999).toString().padLeft(5, '0');
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  /// 清理文件名中的路径分隔符和特殊字符。
  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
