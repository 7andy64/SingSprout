import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../../../shared/services/audio_service.dart';
import '../../../shared/services/sound_analysis_service.dart';

/// 田野声音实验室 — 状态管理与业务逻辑
///
/// 从 FieldSoundLabPage 的 State 中抽取，职责：
/// - 录音生命周期（开始/停止/倒计时/音量采集）
/// - 录音回放（保存前试听）
/// - AI 真实分析（DashScope qwen-plus，失败时回退模拟）
/// - 本周探索任务进度计算
class FieldSoundLabViewModel extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  final SoundAnalysisService _analysisService = SoundAnalysisService();

  // ── Recording state ──
  bool _isRecording = false;
  bool _isStartingRecording = false; // 异步间隙过渡态
  int _recordSecondsRemaining = 30;
  double _currentAmplitude = 0;
  String? _recordedFilePath;

  Timer? _recordTimer;
  StreamSubscription<double>? _amplitudeSub;

  // ── Playback state ──
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  // ── AI analysis result ──
  bool _isAnalyzing = false;
  bool _showAnalysisCard = false;
  SoundType _detectedType = SoundType.unknown;
  double _detectedBpm = 0;
  String _recommendedUse = '';
  String _soundDescription = '';
  bool _isRealAi = false; // 是否来自真实 AI

  // ── Permissions ──
  bool _hasPermission = false;

  // ── Weekly tasks ──
  int _weeklyCollected = 0;
  static const int _weeklyTarget = 5;

  // ═══════════════════════════════════════════════
  //  Getters
  // ═══════════════════════════════════════════════

  bool get isRecording => _isRecording;
  bool get isStartingRecording => _isStartingRecording;
  int get recordSecondsRemaining => _recordSecondsRemaining;
  double get currentAmplitude => _currentAmplitude;
  String? get recordedFilePath => _recordedFilePath;

  bool get isPlaying => _isPlaying;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;

  bool get isAnalyzing => _isAnalyzing;
  bool get showAnalysisCard => _showAnalysisCard;
  SoundType get detectedType => _detectedType;
  double get detectedBpm => _detectedBpm;
  String get recommendedUse => _recommendedUse;
  String get soundDescription => _soundDescription;
  bool get isRealAi => _isRealAi;

  bool get hasPermission => _hasPermission;

  int get weeklyCollected => _weeklyCollected;
  int get weeklyTarget => _weeklyTarget;

  /// 录音剩余进度 0.0 ~ 1.0
  double get recordProgress =>
      _isRecording ? _recordSecondsRemaining / 30 : 0.0;

  /// 回放进度 0.0 ~ 1.0
  double get playbackProgress =>
      _playbackDuration.inMilliseconds > 0
          ? _playbackPosition.inMilliseconds /
              _playbackDuration.inMilliseconds
          : 0.0;

  /// 是否有录音可以回放
  bool get hasRecording => _recordedFilePath != null && !_isRecording;

  // ═══════════════════════════════════════════════
  //  Lifecycle
  // ═══════════════════════════════════════════════

  /// 初始化音频流监听和权限检查。
  void init() {
    _positionSub = _audioService.position.listen((pos) {
      _playbackPosition = pos;
      notifyListeners();
    });
    _durationSub = _audioService.duration.listen((dur) {
      _playbackDuration = dur ?? Duration.zero;
      notifyListeners();
    });
    _checkPermission();
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _recordTimer?.cancel();
    _audioService.stopPlayback();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  //  Permissions
  // ═══════════════════════════════════════════════

  Future<void> _checkPermission() async {
    final granted = await _audioService.hasMicPermission();
    _hasPermission = granted;
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final granted = await _audioService.requestMicPermission();
    _hasPermission = granted;
    notifyListeners();
    return granted;
  }

  // ═══════════════════════════════════════════════
  //  Recording
  // ═══════════════════════════════════════════════

  /// 开始录音，返回错误消息（null = 成功）。
  Future<String?> startRecording() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return 'permission_denied';
    }

    // 标记过渡态，避免 UI 闪烁
    _isStartingRecording = true;
    notifyListeners();

    try {
      // 先停止可能正在进行的回放
      await _audioService.stopPlayback();
      _isPlaying = false;

      // 清理上一次录音的临时文件，防止存储泄漏
      if (_recordedFilePath != null) {
        try {
          final oldFile = File(_recordedFilePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {
          // 删除失败不影响新录音
        }
      }

      final path = await _audioService.startWavRecording();
      if (path == null) {
        _isStartingRecording = false;
        notifyListeners();
        return 'recording_failed';
      }

      _isRecording = true;
      _recordSecondsRemaining = 30;
      _recordedFilePath = path;
      _showAnalysisCard = false;

      // Volume stream
      _amplitudeSub = _audioService.amplitude.listen((amp) {
        _currentAmplitude = (amp + 60) / 60;
        notifyListeners();
      });

      // Countdown timer
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordSecondsRemaining--;
        notifyListeners();
        if (_recordSecondsRemaining <= 0) {
          stopRecording();
        }
      });

      _isStartingRecording = false;
      notifyListeners();
      return null; // success
    } catch (e) {
      _isStartingRecording = false;
      debugPrint('[FieldSoundLabVM] startRecording error: $e');
      notifyListeners();
      return 'recording_error';
    }
  }

  /// 停止录音，触发 AI 模拟分析。
  Future<void> stopRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();

    final path = await _audioService.stopRecording();
    _isRecording = false;
    _currentAmplitude = 0;
    _recordedFilePath = path;

    notifyListeners();

    if (path != null) {
      _runAnalysis();
    }
  }

  // ═══════════════════════════════════════════════
  //  Playback（保存前试听）
  // ═══════════════════════════════════════════════

  /// 播放录好的声音。
  Future<void> playRecording() async {
    if (_recordedFilePath == null) return;
    await _audioService.playAudio(_recordedFilePath!);
    _isPlaying = true;
    notifyListeners();
  }

  /// 暂停/继续回放。
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioService.pausePlayback();
      _isPlaying = false;
    } else {
      await _audioService.resumePlayback();
      _isPlaying = true;
    }
    notifyListeners();
  }

  /// 停止回放。
  Future<void> stopPlayback() async {
    await _audioService.stopPlayback();
    _isPlaying = false;
    _playbackPosition = Duration.zero;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  //  Weekly Tasks
  // ═══════════════════════════════════════════════

  /// 根据用户声音库计算本周已采集的声音类型数量。
  ///
  /// 统计本周一到今天之间采集的不同 [SoundType] 种类数。
  /// 每周任务目标为采集 5 种不同类型的声音。
  void updateWeeklyProgress(List<SoundType> collectedTypesThisWeek) {
    final uniqueTypes = collectedTypesThisWeek.toSet();
    final newCount = uniqueTypes.length.clamp(0, _weeklyTarget);
    if (newCount == _weeklyCollected) return;
    _weeklyCollected = newCount;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  //  AI Simulation（暂保留模拟）
  // ═══════════════════════════════════════════════

  /// 执行 AI 分析（真实 DashScope → 失败时回退模拟）
  Future<void> _runAnalysis() async {
    if (_recordedFilePath == null) return;

    _isAnalyzing = true;
    notifyListeners();

    // 尝试真实 AI 分析
    if (_recordedFilePath != null) {
      final result = await _analysisService.analyze(
        _recordedFilePath!,
        recordingContext: '田野声音采集，录制于 ${_formatNow()}',
      );

      if (result != null) {
        _detectedType = result.type;
        _detectedBpm = result.estimatedBpm;
        _recommendedUse = result.recommendedUse;
        _soundDescription = result.description;
        _isRealAi = true;
        _isAnalyzing = false;
        _showAnalysisCard = true;
        notifyListeners();
        return;
      }
    }

    // 回退到模拟分析
    _simulateFallback();
  }

  /// AI 不可用时的模拟分析回退
  void _simulateFallback() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final rng = Random();
      final types = SoundType.values;
      final sampleBpm = [72.0, 96.0, 108.0, 120.0, 140.0][rng.nextInt(5)];
      final type = types[rng.nextInt(types.length)];

      final useHints = <SoundType, String>{
        SoundType.nature: '这个声音适合做背景环境音，搭配钢琴旋律效果很好',
        SoundType.animal: '这个声音适合做节奏点缀，试试放在副歌段落',
        SoundType.humanVoice: '这段人声适合做旋律主线，可以试试调音或变调',
        SoundType.mechanical: '这个声音适合做打击乐底子，试试循环播放',
        SoundType.unknown: '这个声音很有特色，可以试试不同的音乐风格',
      };

      final descriptions = <SoundType, String>{
        SoundType.nature: '自然之声，像大自然的悄悄话',
        SoundType.animal: '小动物的歌声，充满生命力',
        SoundType.humanVoice: '你的声音真特别，独一无二',
        SoundType.mechanical: '有趣的机械节奏，像机器人在跳舞',
        SoundType.unknown: '神秘的声音，等着你去发现',
      };

      _detectedType = type;
      _detectedBpm = sampleBpm;
      _recommendedUse = useHints[type]!;
      _soundDescription = descriptions[type]!;
      _isRealAi = false;
      _isAnalyzing = false;
      _showAnalysisCard = true;
      notifyListeners();
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    final period = now.hour < 6 ? '深夜' : now.hour < 12 ? '上午' : now.hour < 18 ? '下午' : '晚上';
    return '$period${now.hour}点';
  }

  // ═══════════════════════════════════════════════
  //  Static helpers
  // ═══════════════════════════════════════════════

  static String typeIcon(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return '🗣️';
      case SoundType.animal: return '🐦';
      case SoundType.nature: return '🌿';
      case SoundType.mechanical: return '⚙️';
      case SoundType.unknown: return '❓';
    }
  }

  static Color? typeColor(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return const Color(0xFFEF5350);
      case SoundType.animal: return const Color(0xFFFF9800);
      case SoundType.nature: return const Color(0xFF7CB342);
      case SoundType.mechanical: return const Color(0xFF7C4DFF);
      case SoundType.unknown: return const Color(0xFF78909C);
    }
  }
}
