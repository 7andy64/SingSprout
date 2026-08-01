import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/enums.dart';
import '../../../shared/services/audio_service.dart';
import '../../../shared/services/file_storage_service.dart';
import '../../../shared/utils/audio_generator.dart' show AudioGenerator, GenerationResult, PipelineProgress;
import '../../../shared/services/wav_synthesizer.dart' show ModulationParams;
import '../../../shared/services/wav_synthesizer_isolate.dart' show WavSynthesizerIsolate;

/// ViewModel for CreativeFlowPage — manages all state and business logic.
///
/// Animations stay in the Page (need TickerProvider). This class is pure
/// business logic and state, independent of the widget tree.
class CreativeFlowViewModel extends ChangeNotifier {
  // ── Stage ──
  CreativeFlowStage stage = CreativeFlowStage.idle;

  // ── Style & mood ──
  StyleSeed selectedStyle = StyleSeed.morningDew;
  MoodColor? selectedMood;
  double temperature = 0.5;
  double speed = 0.5;
  double instrumentMix = 0.5;

  // ── Playback ──
  bool isPlaying = false;
  Duration playPosition = Duration.zero;
  Duration playDuration = Duration.zero;

  // ── Recording ──
  String? recordedFilePath;
  double currentAmplitude = 0.0;
  double smoothAmplitude = 0.0;
  DateTime? lastSoundTime;
  DateTime? recordingStartTime;

  // ── Generation ──
  GenerationResult? generationResult;
  bool isGenerating = false;
  PipelineProgress? pipelineProgress;
  int completedStageIndex = -1;

  // ── Modulation ──
  ModulationParams modParams = ModulationParams.neutral;
  bool isReRendering = false;

  // ── Speech ──
  bool speechMode = false;
  String? speechText;

  // ── Internal ──
  final AudioPlayer audioPlayer;
  StreamSubscription<double>? _ampSub;
  Timer? _reRenderTimer;

  CreativeFlowViewModel({AudioPlayer? player})
      : audioPlayer = player ?? AudioPlayer() {
    audioPlayer.positionStream.listen((p) {
      playPosition = p;
      notifyListeners();
    });
    audioPlayer.durationStream.listen((d) {
      playDuration = d ?? Duration.zero;
      notifyListeners();
    });
    audioPlayer.playerStateStream.listen((s) {
      isPlaying = s.playing;
      notifyListeners();
    });
    audioPlayer.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        audioPlayer.seek(Duration.zero);
        audioPlayer.pause();
      }
    });
  }

  Color styleAccentColor() {
    switch (selectedStyle) {
      case StyleSeed.morningDew:
        return const Color(0xFF7BC67E);
      case StyleSeed.mountainStream:
        return const Color(0xFF4D96FF);
      case StyleSeed.frogDrum:
        return const Color(0xFFFF8C42);
      case StyleSeed.random:
        return const Color(0xFF9B59B6);
    }
  }

  // ── Recording ──

  Future<void> startRecording() async {
    recordingStartTime = DateTime.now();
    lastSoundTime = DateTime.now();
    smoothAmplitude = 0.0;
    _ampSub?.cancel();
    _ampSub = AudioService().amplitude.listen((amp) {
      final normAmp = (amp + 60) / 60;
      smoothAmplitude = smoothAmplitude * 0.75 + normAmp * 0.25;
      currentAmplitude = smoothAmplitude;
      if (smoothAmplitude > 0.10) {
        lastSoundTime = DateTime.now();
      }
      notifyListeners();
    });
    try {
      recordedFilePath = await AudioService().startWavRecording();
      debugPrint('[CreativeFlow] start recording: $recordedFilePath');
    } catch (e) {
      debugPrint('[CreativeFlow] recording start failed: $e');
      _ampSub?.cancel();
    }
  }

  Future<String?> stopRecording() async {
    _ampSub?.cancel();
    currentAmplitude = 0.0;
    recordingStartTime = null;
    final path = await AudioService().stopRecording();
    recordedFilePath = path;
    final dur = AudioService().lastDuration;
    debugPrint('[CreativeFlow] stop recording: $path, duration: $dur');
    notifyListeners();
    return path;
  }

  Future<void> cleanupRecording() async {
    _ampSub?.cancel();
    currentAmplitude = 0.0;
    recordingStartTime = null;
    notifyListeners();
    await AudioService().stopRecording();
  }

  // ── Generation ──

  Future<void> generateMusic() async {
    isGenerating = true;
    generationResult = null;
    pipelineProgress = null;
    completedStageIndex = -1;
    notifyListeners();

    if (recordedFilePath != null) {
      try {
        generationResult = await AudioGenerator.generateFromHumming(
          wavFilePath: recordedFilePath!,
          styleSeed: selectedStyle,
          recordingDuration: AudioService().lastDuration,
          speechText: speechText,
          onProgress: (p) {
            pipelineProgress = p;
            if (p.fraction >= 1.0) {
              completedStageIndex = 4;
            } else if (p.fraction >= 0.90) {
              completedStageIndex = 4;
            } else if (p.fraction >= 0.70) {
              completedStageIndex = 3;
            } else if (p.fraction >= 0.50) {
              completedStageIndex = 2;
            } else if (p.fraction >= 0.30) {
              completedStageIndex = 1;
            } else {
              completedStageIndex = 0;
            }
            notifyListeners();
          },
        );
      } catch (e) {
        debugPrint('[CreativeFlow] AI generation failed: $e');
        generationResult = await AudioGenerator.generateTestTone(
          styleSeed: selectedStyle.name,
          durationSec: 3.0,
        );
      }
    } else {
      generationResult = await AudioGenerator.generateTestTone(
        styleSeed: selectedStyle.name,
        durationSec: 3.0,
      );
    }
    isGenerating = false;
    notifyListeners();
  }

  // ── Playback ──

  Future<void> togglePlayPause() async {
    if (generationResult == null) return;
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      try {
        await audioPlayer.setFilePath(generationResult!.audioPath);
        await audioPlayer.play();
      } catch (e) {
        debugPrint('[CreativeFlow] playback failed: $e');
      }
    }
  }

  String formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Modulation (re-render) ──

  Future<void> triggerReRender() async {
    if (generationResult == null || isReRendering) return;

    _reRenderTimer?.cancel();
    _reRenderTimer = Timer(const Duration(milliseconds: 250), () async {
      isReRendering = true;
      notifyListeners();

      try {
        final newPath = FileStorageService().generateMusicPath(
          styleSeed: selectedStyle.name,
          extension: 'wav',
        );
        await WavSynthesizerIsolate.renderModulated(
          baseArrangement: generationResult!.arrangement,
          melody: generationResult!.melody,
          style: selectedStyle,
          params: modParams,
          outputPath: newPath,
        );

        final wasPlaying = isPlaying;
        await audioPlayer.setFilePath(newPath);
        if (wasPlaying) await audioPlayer.play();

        generationResult = GenerationResult(
          audioPath: newPath,
          arrangement: generationResult!.arrangement,
          melody: generationResult!.melody,
          melodyNoteCount: generationResult!.melodyNoteCount,
        );
      } catch (e) {
        debugPrint('[CreativeFlow] re-render failed: $e');
      } finally {
        isReRendering = false;
        notifyListeners();
      }
    });
  }

  // ── Public setters (avoid widgets calling protected notifyListeners) ──

  void selectStyle(StyleSeed style) {
    selectedStyle = style;
    notifyListeners();
  }

  void selectMood(MoodColor? mood) {
    selectedMood = mood;
    notifyListeners();
  }

  void updateModulation({
    double? temperature,
    double? speed,
    double? instrumentMix,
  }) {
    if (temperature != null) this.temperature = temperature;
    if (speed != null) this.speed = speed;
    if (instrumentMix != null) this.instrumentMix = instrumentMix;
    modParams = ModulationParams(
      temperature: this.temperature,
      speed: this.speed * 1.5 + 0.5,
      instrumentMix: this.instrumentMix,
    );
    notifyListeners();
    triggerReRender();
  }

  // ── Helpers ──

  int silentSeconds() {
    if (lastSoundTime == null) return 0;
    return DateTime.now().difference(lastSoundTime!).inSeconds;
  }

  int elapsedRecordingSeconds() {
    if (recordingStartTime == null) return 0;
    return DateTime.now().difference(recordingStartTime!).inSeconds;
  }

  String elapsedString() {
    final sec = elapsedRecordingSeconds();
    return '${(sec ~/ 60)}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  double recordingRingProgress() =>
      (elapsedRecordingSeconds() / 15.0).clamp(0.0, 1.0);

  bool get showSilentGuide => smoothAmplitude < 0.10 && silentSeconds() >= 2;

  bool get showLongPressHint => stage == CreativeFlowStage.recording;

  @override
  void dispose() {
    audioPlayer.dispose();
    _ampSub?.cancel();
    _reRenderTimer?.cancel();
    super.dispose();
  }
}

/// Stage enum — extracted so widgets can reference it.
enum CreativeFlowStage {
  idle,
  recording,
  stylePick,
  generating,
  editing,
}
