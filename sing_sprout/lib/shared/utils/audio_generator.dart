import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/constants/enums.dart';
import '../services/audio_processor.dart';
import '../services/arrangement_engine.dart';
import '../services/dash_scope_service.dart';
import '../services/wav_synthesizer.dart';
import '../services/file_storage_service.dart';

/// Result of the full generation pipeline.
class GenerationResult {
  final String audioPath;
  final Arrangement arrangement;
  final List<MidiNoteEvent> melody;
  final int melodyNoteCount;

  const GenerationResult({
    required this.audioPath,
    required this.arrangement,
    required this.melody,
    required this.melodyNoteCount,
  });
}

/// Progress event emitted during pipeline execution.
class PipelineProgress {
  final String stageName;
  final String icon;
  final double fraction; // 0.0–1.0
  final String? detail;  // e.g. "找到 7 个音符"

  const PipelineProgress({
    required this.stageName,
    required this.icon,
    required this.fraction,
    this.detail,
  });

  static const stages = [
    PipelineProgress(stageName: '正在听你的旋律...', icon: '🌱', fraction: 0.08),
    PipelineProgress(stageName: '在旋律中寻找音符', icon: '🔍', fraction: 0.25),
    PipelineProgress(stageName: '找到音符了！',       icon: '🎵', fraction: 0.42),
    PipelineProgress(stageName: 'AI 正在构思编排…',  icon: '🤖', fraction: 0.55),
    PipelineProgress(stageName: '正在编织和弦',       icon: '🎹', fraction: 0.72),
    PipelineProgress(stageName: '音乐马上就好',       icon: '✨', fraction: 0.90),
  ];
}

typedef ProgressCallback = void Function(PipelineProgress progress);

/// AI music generation pipeline orchestrator.
///
/// Full chain: WAV recording → YIN pitch detection → MIDI quantization
/// → rule-based arrangement → WAV synthesis → output file.
///
/// Per optimization plan: 0MB model, fully offline, pure DSP + rules.
class AudioGenerator {
  /// Generate a complete music piece from a humming recording.
  ///
  /// [wavFilePath] — 16-bit 44100Hz mono WAV.
  /// [onProgress] — called at each pipeline stage for UI feedback.
  static Future<GenerationResult> generateFromHumming({
    required String wavFilePath,
    required StyleSeed styleSeed,
    Duration? recordingDuration,
    ProgressCallback? onProgress,
  }) async {
    debugPrint('[AudioGenerator] === Pipeline start ===');
    debugPrint('[AudioGenerator] Input: $wavFilePath, style: ${styleSeed.label}');

    final stopwatch = Stopwatch()..start();
    int melodyNoteCount = 0;

    try {
      // ── Stage 1: Read WAV ──
      onProgress?.call(PipelineProgress.stages[0]);
      final samples = await AudioProcessor.readWav(wavFilePath);
      debugPrint('[AudioGenerator] Stage 1: Read ${samples.length} samples (${(samples.length / 44100).toStringAsFixed(1)}s)');

      // ── Stage 2: YIN pitch detection ──
      onProgress?.call(PipelineProgress.stages[1]);
      final pitchContour = AudioProcessor.detectPitch(samples, 44100);
      final voicedFrames = pitchContour.where((p) => p.frequencyHz > 0).length;
      debugPrint('[AudioGenerator] Stage 2: YIN → ${pitchContour.length} frames, $voicedFrames voiced');

      // ── Stage 3: MIDI quantization ──
      var melody = AudioProcessor.pitchToMidi(pitchContour);
      melodyNoteCount = melody.length;
      debugPrint('[AudioGenerator] Stage 3: Quantized → $melodyNoteCount MIDI notes');
      onProgress?.call(PipelineProgress(
        stageName: '找到音符了！',
        icon: '🎵',
        fraction: 0.50,
        detail: melodyNoteCount > 0 ? '发现了 $melodyNoteCount 个音符' : '正在创作一段旋律...',
      ));

      // Fallback: silent / too short
      if (melody.isEmpty) {
        debugPrint('[AudioGenerator] ⚠️ No melody detected, generating fallback');
        melody = _generateFallbackMelody(
          (recordingDuration?.inSeconds ?? 4).clamp(2, 10).toDouble(),
        );
        melodyNoteCount = melody.length;
      }

      // ── Stage 3.5: AI enhancement (optional, graceful fallback) ──
      onProgress?.call(PipelineProgress.stages[3]);
      final totalDuration = melody.isNotEmpty
          ? (melody.map((n) => n.startSeconds + n.durationSeconds).reduce(max) + 1.0).clamp(3.0, 30.0)
          : (recordingDuration?.inSeconds ?? 4).clamp(3, 12).toDouble();
      final tonicMidi = _guessTonic(melody);

      Arrangement arrangement;
      String? aiMoodNote;
      final melodyData = melody.map((n) => {
        'noteNumber': n.noteNumber,
        'startSeconds': n.startSeconds,
        'durationSeconds': n.durationSeconds,
        'velocity': n.velocity,
      }).toList();

      try {
        final recipe = await DashScopeService().enhanceArrangement(
          melodyNotes: melodyData,
          styleLabel: styleSeed.label,
          totalDuration: totalDuration,
          tonicMidi: tonicMidi,
        );

        if (recipe != null) {
          arrangement = ArrangementEngine.arrangeWithRecipe(
            melody: melody,
            recipe: recipe,
            tonicMidi: tonicMidi,
            durationOverride: totalDuration,
          );
          aiMoodNote = recipe.moodNote;
          debugPrint('[AudioGenerator] Stage 3.5: AI-enhanced arrangement used');
        } else {
          arrangement = ArrangementEngine.arrange(melody: melody, style: styleSeed, durationOverride: totalDuration);
          debugPrint('[AudioGenerator] Stage 3.5: AI unavailable, using rule engine');
        }
      } catch (_) {
        arrangement = ArrangementEngine.arrange(melody: melody, style: styleSeed, durationOverride: totalDuration);
        debugPrint('[AudioGenerator] Stage 3.5: AI failed, using rule engine');
      }

      debugPrint('[AudioGenerator] Stage 4: Arranged → mel:${arrangement.melody.length} '
          'chd:${arrangement.chords.length} bass:${arrangement.bass.length} '
          'perc:${arrangement.percussion.length}');

      // ── Stage 5: WAV synthesis ──
      onProgress?.call(PipelineProgress.stages[4]);
      if (aiMoodNote != null) {
        onProgress?.call(PipelineProgress(
          stageName: 'AI 说: $aiMoodNote',
          icon: '🤖',
          fraction: 0.85,
          detail: aiMoodNote,
        ));
      }
      final outputPath = FileStorageService().generateMusicPath(
        styleSeed: styleSeed.name,
        extension: 'wav',
      );
      await WavSynthesizer.renderToFile(
        arrangementOrNotes: arrangement,
        style: styleSeed,
        outputPath: outputPath,
        totalDuration: arrangement.totalDurationSeconds,
      );

      stopwatch.stop();
      debugPrint('[AudioGenerator] Stage 5: Synthesized → $outputPath '
          '(${arrangement.totalDurationSeconds.toStringAsFixed(1)}s)');
      debugPrint('[AudioGenerator] === Pipeline complete in ${stopwatch.elapsedMilliseconds}ms ===');

      onProgress?.call(const PipelineProgress(
        stageName: '完成！',
        icon: '🌟',
        fraction: 1.0,
        detail: '你的音乐已经准备好了',
      ));

      return GenerationResult(
        audioPath: outputPath,
        arrangement: arrangement,
        melody: melody,
        melodyNoteCount: melodyNoteCount,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AudioGenerator] Pipeline error (${stopwatch.elapsedMilliseconds}ms): $e');
      final fallbackPath = await _generateEmergencyPath(styleSeed: styleSeed.name);
      final fallbackMelody = _generateFallbackMelody((recordingDuration?.inSeconds ?? 4).clamp(2, 10).toDouble());
      final fallbackArr = ArrangementEngine.arrange(melody: fallbackMelody, style: styleSeed);
      return GenerationResult(
        audioPath: fallbackPath,
        arrangement: fallbackArr,
        melody: fallbackMelody,
        melodyNoteCount: fallbackMelody.length,
      );
    }
  }

  /// Legacy API.
  static Future<GenerationResult> generateTestTone({
    required String styleSeed,
    double durationSec = 3.0,
  }) async {
    final path = await _generateEmergencyPath(styleSeed: styleSeed, durationSec: durationSec);
    final melody = _generateFallbackMelody(durationSec);
    final arr = ArrangementEngine.arrange(melody: melody, style: StyleSeed.morningDew);
    return GenerationResult(
      audioPath: path,
      arrangement: arr,
      melody: melody,
      melodyNoteCount: melody.length,
    );
  }

  // ── Fallback generators ──

  /// Quick tonic guess from melody for AI prompt.
  static int _guessTonic(List<MidiNoteEvent> melody) {
    if (melody.isEmpty) return 60;
    final avg = melody.map((n) => n.noteNumber).reduce((a, b) => a + b) ~/ melody.length;
    return (avg ~/ 12) * 12 + (avg % 12); // round to pitch class
  }

  static List<MidiNoteEvent> _generateFallbackMelody(double durationSeconds) {
    final noteLen = (durationSeconds / 4).clamp(0.4, 1.5);
    final notes = <MidiNoteEvent>[];
    final baseNotes = [62, 65, 69, 67];
    for (var i = 0; i < baseNotes.length && i * noteLen < durationSeconds; i++) {
      notes.add(MidiNoteEvent(
        noteNumber: baseNotes[i],
        startSeconds: i * noteLen,
        durationSeconds: noteLen * 0.85,
        velocity: 0.7,
      ));
    }
    return notes;
  }

  static Future<String> _generateEmergencyPath({
    required String styleSeed,
    double durationSec = 3.0,
  }) async {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationSec).round();
    double baseFreq;
    switch (styleSeed) {
      case 'morningDew': baseFreq = 523.25; break;
      case 'mountainStream': baseFreq = 329.63; break;
      case 'frogDrum': baseFreq = 440.0; break;
      default: baseFreq = 440.0;
    }
    final frequencies = [baseFreq, baseFreq * 1.25, baseFreq * 1.5];
    final samples = Float64List(numSamples);
    final notesPerNote = numSamples ~/ frequencies.length;
    for (var i = 0; i < numSamples; i++) {
      final noteIndex = (i ~/ notesPerNote).clamp(0, frequencies.length - 1);
      final envelope = i < 2205 ? i / 2205.0 : (i > numSamples - 2205 ? (numSamples - i) / 2205.0 : 1.0);
      samples[i] = sin(2 * pi * frequencies[noteIndex] * i / sampleRate) * envelope * 0.6;
    }
    final outPath = FileStorageService().generateMusicPath(styleSeed: styleSeed, extension: 'wav');
    await AudioProcessor.writeWav(outPath, samples, sampleRate);
    return outPath;
  }
}
