import 'package:flutter/foundation.dart';

/// 音频录制与播放状态管理
enum AudioStatus { idle, recording, processing, playing, paused }

class AudioProvider extends ChangeNotifier {
  AudioStatus _status = AudioStatus.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<double>? _waveformData;

  AudioStatus get status => _status;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  List<double>? get waveformData => _waveformData;
  bool get isRecording => _status == AudioStatus.recording;

  void startRecording() {
    _status = AudioStatus.recording;
    _currentPosition = Duration.zero;
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
