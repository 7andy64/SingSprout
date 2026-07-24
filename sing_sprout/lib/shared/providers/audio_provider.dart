import 'dart:async';
import 'package:flutter/foundation.dart';

/// 音频录制与播放状态管理
enum AudioStatus { idle, recording, processing, playing, paused }

class AudioProvider extends ChangeNotifier {
  AudioStatus _status = AudioStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<double>? _waveformData;

  /// 来电等中断时自动保存的片段路径
  String? _savedFragmentPath;

  AudioStatus get status => _status;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  List<double>? get waveformData => _waveformData;
  bool get isRecording => _status == AudioStatus.recording;
  String? get savedFragmentPath => _savedFragmentPath;
  bool get hasSavedFragment => _savedFragmentPath != null;

  void startRecording() {
    _status = AudioStatus.recording;
    _currentPosition = Duration.zero;
    _savedFragmentPath = null;
    notifyListeners();
  }

  void stopRecording() {
    _status = AudioStatus.processing;
    notifyListeners();
  }

  void processingComplete() {
    _status = AudioStatus.idle;
    notifyListeners();
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

  void startPlaying(Duration totalDuration) {
    _status = AudioStatus.playing;
    _totalDuration = totalDuration;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  void updatePosition(Duration position) {
    _currentPosition = position;
    notifyListeners();
  }

  void pausePlayback() {
    _status = AudioStatus.paused;
    notifyListeners();
  }

  void resumePlayback() {
    _status = AudioStatus.playing;
    notifyListeners();
  }

  void stopPlayback() {
    _status = AudioStatus.idle;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  void updateWaveform(List<double> data) {
    _waveformData = data;
    notifyListeners();
  }
}
