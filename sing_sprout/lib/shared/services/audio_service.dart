import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' show AudioRecorder, RecordConfig, AudioEncoder, Amplitude;
import 'package:permission_handler/permission_handler.dart';
import '../services/file_storage_service.dart';

/// 本地音频服务 — 录音、播放与中断处理
///
/// 使用 record 插件实现跨平台录音，支持 m4a(AAC) 格式。
/// 录音文件保存到应用私有目录的 recordings/ 子目录。
/// 处理来电中断、权限申请、存储空间不足等异常场景。
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final _audioRecorder = AudioRecorder();
  final _player = AudioPlayer();
  final _fileStorage = FileStorageService();

  bool _isRecording = false;
  bool _isPlaying = false;
  DateTime? _recordingStartedAt;

  /// 当前录音文件的完整路径（开始录音后赋值）
  String? _currentRecordingPath;

  /// 中断时保存的片段路径（null 表示未被中断过）
  String? _savedFragmentPath;

  /// 上一次权限检查结果的缓存
  bool? _cachedMicPermission;

  /// 最近一次停止录音后的时长（stopRecording 后 _recordingStartedAt 会被清空，
  /// 通过此字段保存时长供调用方获取）
  Duration? _lastDuration;

  // ── Getters ──

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get savedFragmentPath => _savedFragmentPath;
  String? get currentRecordingPath => _currentRecordingPath;

  /// 当前录音的实时时长（录制中有效，录制停止后返回 null）。
  Duration? get recordingDuration {
    if (_recordingStartedAt == null) return null;
    return DateTime.now().difference(_recordingStartedAt!);
  }

  /// 最近一次停止录音后的真实时长（录制停止后有效）。
  Duration? get lastDuration => _lastDuration;

  Stream<Duration> get position => _player.onPositionChanged;
  Stream<Duration> get duration => _player.onDurationChanged;
  Stream<PlayerState> get playerState => _player.onPlayerStateChanged;
  Stream<double> get amplitude =>
      amplitudeStream.map((a) => a.current.clamp(-60.0, 0.0));

  // ── 权限处理 ──

  /// 请求麦克风权限。
  ///
  /// Android 还需要存储权限（Android 12 及以下），
  /// iOS 只需麦克风权限（iOS 的隐私沙盒不暴露文件系统）。
  ///
  /// 返回 true 表示所有必要权限已授予。
  Future<bool> requestMicPermission() async {
    // 先检查缓存，避免重复弹窗
    if (_cachedMicPermission == true) return true;

    // 请求麦克风权限
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[AudioService] 麦克风权限被拒绝: $micStatus');
      _cachedMicPermission = false;
      return false;
    }

    // Android 12 及以下：需要存储权限来写入录音文件
    if (Platform.isAndroid) {
      // Android 13+：使用 scoped storage，不需要额外存储权限
      // Android 12-：需要 WRITE_EXTERNAL_STORAGE
      // 这里使用应用私有目录（getApplicationDocumentsDirectory），
      // 不需要外部存储权限，但保留此逻辑以备扩展。
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
        // 即使存储权限被拒，使用应用私有目录仍可正常写入
        debugPrint('[AudioService] 存储权限未授予，使用应用私有目录');
      }
    }

    _cachedMicPermission = true;
    return true;
  }

  /// 检查麦克风权限是否已授予（不弹窗）。
  Future<bool> hasMicPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  // ── 录音 ──

  /// 开始录音（AAC 格式，通用场景）。
  ///
  /// 录音文件以 [当前时间戳].m4a 命名，保存到 FileStorageService
  /// 管理的 recordings/ 目录。
  ///
  /// 返回录音文件的完整路径，如果权限不足或发生错误则返回 null。
  ///
  /// 可能抛出 [AudioRecordException] 包含具体错误信息。
  Future<String?> startRecording() async {
    return _startRecordingInternal(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      extension: 'm4a',
    );
  }

  /// 开始录音（WAV PCM 格式，用于哼唱分析）。
  ///
  /// WAV 录制用于 AI 流水线的音高检测阶段。
  /// 16-bit PCM, 44100Hz, 单声道。
  ///
  /// 返回录音文件的完整路径，如果权限不足或发生错误则返回 null。
  Future<String?> startWavRecording() async {
    return _startRecordingInternal(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      extension: 'wav',
    );
  }

  Future<String?> _startRecordingInternal(RecordConfig config, {required String extension}) async {
    // ── 1. 状态检查 ──
    if (_isRecording) {
      debugPrint('[AudioService] 已在录音中，忽略重复请求');
      return _currentRecordingPath;
    }

    // ── 2. 权限检查 ──
    final hasPermission = await requestMicPermission();
    if (!hasPermission) {
      throw AudioRecordException('麦克风权限未授予，无法开始录音。'
          '请在系统设置中允许声芽访问麦克风。');
    }

    // ── 3. 检查录音器是否可用 ──
    if (!await _audioRecorder.hasPermission()) {
      throw AudioRecordException('录音权限检查失败，请确认系统设置中已授权。');
    }

    // ── 4. 生成文件路径 ──
    _currentRecordingPath = _fileStorage.generateRecordingPath(extension: extension);

    // ── 5. 确保目录存在 ──
    try {
      final dir = Directory(_fileStorage.recordingsDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      throw AudioRecordException('无法创建录音目录: $e');
    }

    // ── 6. 开始录音 ──
    try {
      final filePath = _currentRecordingPath!;
      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;
      _savedFragmentPath = null;
      _recordingStartedAt = DateTime.now();

      debugPrint('[AudioService] ✅ 开始录音 → $filePath');
      return filePath;
    } on Exception catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
      throw AudioRecordException('录音启动失败: $e');
    } on FileSystemException catch (e) {
      // 存储空间不足或路径不可写
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
      throw AudioRecordException(
        '存储空间不足或文件写入失败: ${e.message}。请清理存储后重试。',
      );
    } catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
      throw AudioRecordException('录音启动时发生未知错误: $e');
    }
  }

  /// 停止录音。
  ///
  /// 返回录音文件的路径，或 null（如果未在录音中或发生错误）。
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final duration = recordingDuration;
    final filePath = _currentRecordingPath;

    try {
      // 停止前先捕获时长
      _lastDuration = recordingDuration;
      // 停止录音器
      final savedPath = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;

      // 验证保存结果
      if (savedPath == null || savedPath.isEmpty) {
        debugPrint('[AudioService] ⚠️ 录音停止但未返回文件路径');
        return null;
      }

      // 检查文件是否有效
      final file = File(savedPath);
      if (!await file.exists()) {
        debugPrint('[AudioService] ⚠️ 录音文件不存在: $savedPath');
        return null;
      }

      final fileSize = await file.length();
      if (fileSize < 100) {
        // 文件太小，可能录制失败
        debugPrint('[AudioService] ⚠️ 录音文件异常小而丢弃(${fileSize}B): $savedPath');
        await file.delete();
        return null;
      }

      debugPrint('[AudioService] ✅ 录音完成 — $savedPath '
          '(时长: $duration, 大小: ${(fileSize / 1024).toStringAsFixed(1)} KB)');
      return savedPath;
    } on Exception catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
      debugPrint('[AudioService] 停止录音异常: $e');

      // 尝试清理残留文件
      if (filePath != null) {
        try {
          final f = File(filePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      return null;
    } catch (e) {
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
      debugPrint('[AudioService] 停止录音时发生未知错误: $e');
      return null;
    }
  }

  /// 取消录音（不保存文件）。
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    final filePath = _currentRecordingPath;
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    _isRecording = false;
    _recordingStartedAt = null;

    // 删除录音文件
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _currentRecordingPath = null;
    debugPrint('[AudioService] 录音已取消');
  }

  /// 获取当前录音音量幅度（用于波形显示）。
  ///
  /// 每 100ms 采样一次，返回 Amplitude 对象包含 current 和 max 值。
  Stream<Amplitude> get amplitudeStream =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  // ── 中断处理 ──

  /// 被电话等中断时自动保存片段。
  ///
  /// 调用后 [savedFragmentPath] 指向保存的文件。
  /// 录音超过 1 秒才保存，不足 1 秒自动丢弃。
  /// 用户返回时可从此路径恢复录音。
  Future<String?> saveOnInterrupt() async {
    if (!_isRecording) return null;

    final duration = recordingDuration;
    if (duration == null || duration.inSeconds < 1) {
      // 录制不到 1 秒，不值得保存
      await cancelRecording();
      debugPrint('[AudioService] 📞 来电中断 — 录音不足1秒，丢弃片段');
      return null;
    }

    // 正常停止（record 插件会自动保存）
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStartedAt = null;

      // 复制到 recovery 目录作为备份
      if (path != null) {
        final docsDir = await getApplicationDocumentsDirectory();
        final recoveryDir = Directory('${docsDir.path}/recovery');
        if (!await recoveryDir.exists()) {
          await recoveryDir.create(recursive: true);
        }

        final filename =
            'fragment_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final recoveryPath = '${recoveryDir.path}/$filename';
        await File(path).copy(recoveryPath);

        _savedFragmentPath = recoveryPath;
        _currentRecordingPath = null;

        debugPrint('[AudioService] 📞 来电中断 — 已保存片段($duration):'
            ' $recoveryPath');
        return recoveryPath;
      }
    } catch (e) {
      debugPrint('[AudioService] 📞 中断保存失败: $e');
      _isRecording = false;
      _recordingStartedAt = null;
      _currentRecordingPath = null;
    }
    return null;
  }

  /// 清除已保存的片段（用户确认放弃或不需恢复时调用）。
  Future<void> clearSavedFragment() async {
    if (_savedFragmentPath != null) {
      try {
        final file = File(_savedFragmentPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _savedFragmentPath = null;
    }
  }

  /// 获取 recovery 目录下所有已保存的片段。
  Future<List<File>> getSavedFragments() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryDir = Directory('${docsDir.path}/recovery');
      if (!await recoveryDir.exists()) return [];
      final files = <File>[];
      await for (final entity in recoveryDir.list()) {
        if (entity is File && entity.path.endsWith('.m4a')) {
          files.add(entity);
        }
      }
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return [];
    }
  }

  // ── 播放 ──

  /// 播放音频文件（预留接口，由 just_audio 调用方实现）。
  Future<void> playAudio(String filePath) async {
    try {
      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[AudioService] playAudio error: $e');
      _isPlaying = false;
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('[AudioService] stopPlayback error: $e');
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioService] pausePlayback error: $e');
    }
  }

  Future<void> resumePlayback() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('[AudioService] resumePlayback error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioService] seek error: $e');
    }
  }

  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AudioService] deleteRecording error: $e');
      return false;
    }
  }

  Future<List<String>> listRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/singsprout/recordings');
      if (!await recordingsDir.exists()) return [];
      return recordingsDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList();
    } catch (e) {
      debugPrint('[AudioService] listRecordings error: $e');
      return [];
    }
  }

  /// 释放录音器资源。
  Future<void> dispose() async {
    if (_isRecording) {
      try { await _audioRecorder.stop(); } catch (_) {}
    }
    _isRecording = false;
    _isPlaying = false;
    _savedFragmentPath = null;
    _currentRecordingPath = null;
    try { _audioRecorder.dispose(); } catch (_) {}
  }
}

/// 录音过程中抛出的异常，包含用户可读的错误描述。
class AudioRecordException implements Exception {
  final String message;
  const AudioRecordException(this.message);

  @override
  String toString() => 'AudioRecordException: $message';
}
