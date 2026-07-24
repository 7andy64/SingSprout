import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地音频服务 — 录音、播放与中断处理
///
/// MVP 阶段录音使用 stub 实现，但中断恢复逻辑完整：
/// 来电话断时自动保存已录制片段，用户回来后可继续。
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  bool _isRecording = false;
  bool _isPlaying = false;
  DateTime? _recordingStartedAt;

  /// 中断时保存的片段路径（null 表示未被中断过）
  String? _savedFragmentPath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get savedFragmentPath => _savedFragmentPath;
  Duration? get recordingDuration {
    if (_recordingStartedAt == null) return null;
    return DateTime.now().difference(_recordingStartedAt!);
  }

  Future<bool> requestMicPermission() async => true;

  // ── 录音 ──

  Future<String?> startRecording() async {
    _isRecording = true;
    _savedFragmentPath = null;
    _recordingStartedAt = DateTime.now();
    debugPrint('[AudioService] 开始录音');
    return 'current_recording.m4a';
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final duration = recordingDuration;
    _isRecording = false;
    _recordingStartedAt = null;
    debugPrint('[AudioService] 停止录音，时长: $duration');
    return 'current_recording.m4a';
  }

  /// 被电话等中断时自动保存片段
  ///
  /// 调用后 [_savedFragmentPath] 指向保存的文件。
  /// 用户返回时可从此路径恢复录音。
  Future<String?> saveOnInterrupt() async {
    if (!_isRecording) return null;

    final duration = recordingDuration;
    if (duration == null || duration.inSeconds < 1) {
      // 录制不到 1 秒，不值得保存
      _isRecording = false;
      _recordingStartedAt = null;
      debugPrint('[AudioService] 录音不足1秒，丢弃片段');
      return null;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryDir = Directory('${docsDir.path}/recovery');
      if (!await recoveryDir.exists()) {
        await recoveryDir.create(recursive: true);
      }

      final filename =
          'fragment_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${recoveryDir.path}/$filename';

      // MVP 阶段：写入 stub 文件（真实录音时此处写入实际音频数据）
      final file = File(path);
      await file.writeAsString('audio_fragment_placeholder');

      _savedFragmentPath = path;
      _isRecording = false;
      _recordingStartedAt = null;

      debugPrint('[AudioService] 来电中断 — 已保存片段 ($duration): $path');
      return path;
    } catch (e) {
      debugPrint('[AudioService] 保存片段失败: $e');
      _isRecording = false;
      _recordingStartedAt = null;
      return null;
    }
  }

  /// 清除已保存的片段（用户确认放弃或不需恢复时调用）
  Future<void> clearSavedFragment() async {
    if (_savedFragmentPath != null) {
      try {
        final file = File(_savedFragmentPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _savedFragmentPath = null;
    }
  }

  /// 获取 recovery 目录下所有已保存的片段
  Future<List<File>> getSavedFragments() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryDir = Directory('${docsDir.path}/recovery');
      if (!await recoveryDir.exists()) return [];
      final files = <File>[];
      await for (final entity in recoveryDir.list()) {
        if (entity is File) files.add(entity);
      }
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return [];
    }
  }

  // ── 播放 ──

  Future<void> playAudio(String filePath) async {
    _isPlaying = true;
  }

  Future<void> stopPlayback() async {
    _isPlaying = false;
  }

  void dispose() {
    _isRecording = false;
    _isPlaying = false;
    _savedFragmentPath = null;
  }
}
