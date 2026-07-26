import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../services/audio_service.dart';

enum AudioStatus { idle, recording, processing, playing, paused }

class AudioProvider extends ChangeNotifier {
  final _service = AudioService();
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  AudioStatus _status = AudioStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<double>? _waveformData;
  String? _currentRecordingPath;
  double _currentAmplitude = 0;

  /// 来电等中断时自动保存的片段路径
  String? _savedFragmentPath;

  AudioStatus get status => _status;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  List<double>? get waveformData => _waveformData;
  String? get currentRecordingPath => _currentRecordingPath;
  double get currentAmplitude => _currentAmplitude;
  bool get isRecording => _status == AudioStatus.recording;
  String? get savedFragmentPath => _savedFragmentPath;
  bool get hasSavedFragment => _savedFragmentPath != null;

  AudioProvider() {
    _positionSub = _service.position.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });
    _durationSub = _service.duration.listen((dur) {
      _totalDuration = dur;
      notifyListeners();
    });
    _playerStateSub = _service.playerState.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _status = AudioStatus.idle;
        _currentPosition = Duration.zero;
        notifyListeners();
      }
    });
  }

  Future<bool> requestMicPermission() => _service.requestMicPermission();

  Future<void> startRecording() async {
    final hasPermission = await _service.requestMicPermission();
    if (!hasPermission) return;

    _waveformData = [];
    _status = AudioStatus.recording;
    _currentPosition = Duration.zero;
    _savedFragmentPath = null;
    notifyListeners();

    _ampSub = _service.amplitudeStream.listen((amp) {
      _currentAmplitude = amp.current;
      _waveformData!.add((amp.current + 60) / 60);
      notifyListeners();
    });

    final path = await _service.startRecording();
    if (path != null) {
      _currentRecordingPath = path;
    }
  }

  Future<String?> stopRecording() async {
    _ampSub?.cancel();
    _ampSub = null;

    _status = AudioStatus.processing;
    notifyListeners();

    final path = await _service.stopRecording();
    _currentRecordingPath = path;
    _status = AudioStatus.idle;
    notifyListeners();
    return path;
  }

  /// 来电中断时调用 — 记录已保存的片段路径
  void recordingInterrupted(String savedPath) {
    _savedFragmentPath = savedPath;
    _status = AudioStatus.processing;
    debugPrint('[AudioProvider] 录制被中断，片段已保存: $savedPath');
    notifyListeners();
  }

  /// 清除已保存的片段（用户确认放弃时调用）
  void clearSavedFragment() {
    _savedFragmentPath = null;
    notifyListeners();
  }

  Future<void> startPlaying(String filePath) async {
    _status = AudioStatus.playing;
    _currentPosition = Duration.zero;
    notifyListeners();
    await _service.playAudio(filePath);
  }

  void pausePlayback() {
    _status = AudioStatus.paused;
    notifyListeners();
    _service.pausePlayback();
  }

  void resumePlayback() {
    _status = AudioStatus.playing;
    notifyListeners();
    _service.resumePlayback();
  }

  void stopPlayback() {
    _status = AudioStatus.idle;
    _currentPosition = Duration.zero;
    notifyListeners();
    _service.stopPlayback();
  }

  void seek(Duration position) {
    _service.seek(position);
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _ampSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }
}
