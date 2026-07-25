import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  Stream<RecordState> get recordState => _recorder.onStateChanged();
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => a.current);
  Stream<PlayerState> get playerState => _player.onPlayerStateChanged;
  Stream<Duration> get position => _player.onPositionChanged;
  Stream<Duration> get duration => _player.onDurationChanged;

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<String?> startRecording() async {
    final hasPermission = await requestMicPermission();
    if (!hasPermission) return null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/singsprout/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${recordingsDir.path}/recording_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      return path;
    } catch (e) {
      debugPrint('[AudioService] startRecording error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && File(path).existsSync()) {
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('[AudioService] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

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

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
