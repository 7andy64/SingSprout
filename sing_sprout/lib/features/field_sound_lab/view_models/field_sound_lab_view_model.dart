import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../../../shared/services/audio_service.dart';
import '../../../shared/services/sound_classification_service.dart';

/// 田野声音实验室 — 状态管理与业务逻辑
///
/// 职责：
/// - 录音生命周期（开始/停止/倒计时/音量采集）
/// - 录音回放（保存前试听）
/// - AI 真实分析（YAMNet TFLite 端侧优先，SenseVoice 云端回退）
/// - 本周探索任务进度计算
class FieldSoundLabViewModel extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  final SoundClassificationService _classifier = SoundClassificationService();

  // ── Recording state ──
  bool _isRecording = false;
  bool _isStartingRecording = false;
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
  List<String> _rawLabels = [];
  double _confidence = 0.0;
  bool _isRealAi = false;

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
  List<String> get rawLabels => _rawLabels;
  double get confidence => _confidence;
  bool get isRealAi => _isRealAi;

  bool get hasPermission => _hasPermission;

  int get weeklyCollected => _weeklyCollected;
  int get weeklyTarget => _weeklyTarget;

  double get recordProgress =>
      _isRecording ? _recordSecondsRemaining / 30 : 0.0;

  double get playbackProgress =>
      _playbackDuration.inMilliseconds > 0
          ? _playbackPosition.inMilliseconds /
              _playbackDuration.inMilliseconds
          : 0.0;

  bool get hasRecording => _recordedFilePath != null && !_isRecording;

  // ═══════════════════════════════════════════════
  //  Lifecycle
  // ═══════════════════════════════════════════════

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

  Future<String?> startRecording() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return 'permission_denied';
    }

    _isStartingRecording = true;
    notifyListeners();

    try {
      await _audioService.stopPlayback();
      _isPlaying = false;

      if (_recordedFilePath != null) {
        try {
          final oldFile = File(_recordedFilePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
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

      _amplitudeSub = _audioService.amplitude.listen((amp) {
        _currentAmplitude = (amp + 60) / 60;
        notifyListeners();
      });

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
      return null;
    } catch (e) {
      _isStartingRecording = false;
      debugPrint('[FieldSoundLabVM] startRecording error: $e');
      notifyListeners();
      return 'recording_error';
    }
  }

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
  //  Playback
  // ═══════════════════════════════════════════════

  Future<void> playRecording() async {
    if (_recordedFilePath == null) return;
    await _audioService.playAudio(_recordedFilePath!);
    _isPlaying = true;
    notifyListeners();
  }

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

  Future<void> stopPlayback() async {
    await _audioService.stopPlayback();
    _isPlaying = false;
    _playbackPosition = Duration.zero;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  //  Weekly Tasks
  // ═══════════════════════════════════════════════

  void updateWeeklyProgress(List<SoundType> collectedTypesThisWeek) {
    final uniqueTypes = collectedTypesThisWeek.toSet();
    final newCount = uniqueTypes.length.clamp(0, _weeklyTarget);
    if (newCount == _weeklyCollected) return;
    _weeklyCollected = newCount;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  //  AI Analysis (YAMNet TFLite → SenseVoice cloud)
  // ═══════════════════════════════════════════════

  Future<void> _runAnalysis() async {
    if (_recordedFilePath == null) return;

    _isAnalyzing = true;
    notifyListeners();

    final result = await _classifier.analyze(_recordedFilePath!);

    _detectedType = result.soundType;
    _detectedBpm = result.bpm;
    _recommendedUse = result.recommendedUse;
    _soundDescription = result.rawLabels.isNotEmpty
        ? result.rawLabels.take(3).join('、')
        : '神秘的声音，等着你去发现';
    _rawLabels = result.rawLabels;
    _confidence = result.confidence;
    _isRealAi = _classifier.isYamnetAvailable || result.confidence > 0.5;
    _isAnalyzing = false;
    _showAnalysisCard = true;
    notifyListeners();
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
