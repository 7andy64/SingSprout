import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/constants/enums.dart';
import '../services/audio_processor.dart';
import '../services/arrangement_engine.dart';
import '../services/dash_scope_service.dart';
import '../services/wav_synthesizer_isolate.dart';
import '../services/file_storage_service.dart';

/// Result of the full generation pipeline.
class GenerationResult {
  final String audioPath;
  final Arrangement arrangement;
  final List<MidiNoteEvent> melody;
  final int melodyNoteCount;
  final bool aiEnhanced;
  final String? aiMoodNote;

  const GenerationResult({
    required this.audioPath,
    required this.arrangement,
    required this.melody,
    required this.melodyNoteCount,
    this.aiEnhanced = false,
    this.aiMoodNote,
  });
}

/// Progress event emitted during pipeline execution.
class PipelineProgress {
  final String stageName;
  final String icon;
  final double fraction; // 0.0–1.0
  final String? detail;

  const PipelineProgress({
    required this.stageName,
    required this.icon,
    required this.fraction,
    this.detail,
  });

  static const stages = [
    PipelineProgress(stageName: '正在听你的旋律...', icon: '🌱', fraction: 0.08),
    PipelineProgress(stageName: '在旋律中寻找音符', icon: '🔍', fraction: 0.20),
    PipelineProgress(stageName: '找到音符了！',       icon: '🎵', fraction: 0.35),
    PipelineProgress(stageName: 'AI 正在逐小节编排…',  icon: '🤖', fraction: 0.50),
    PipelineProgress(stageName: '正在编织和弦与节奏', icon: '🎹', fraction: 0.75),
    PipelineProgress(stageName: '音乐马上就好',       icon: '✨', fraction: 0.92),
  ];
}

typedef ProgressCallback = void Function(PipelineProgress progress);

/// AI music generation pipeline orchestrator.
///
/// Full chain: WAV recording → YIN pitch detection → MIDI quantization
/// → [AI full-score generation] → WAV synthesis → output file.
///
/// When AI is available, it writes per-bar accompaniment (bass, chords,
/// percussion, dynamics) directly — no rule templates. Falls back to
/// rule engine when offline or on error.
class AudioGenerator {
  /// Generate a complete music piece from a humming recording.
  ///
  /// [wavFilePath] — 16-bit 44100Hz mono WAV.
  /// [speechText] — optional speech-to-text result from the same recording.
  /// [onProgress] — called at each pipeline stage for UI feedback.
  static Future<GenerationResult> generateFromHumming({
    required String wavFilePath,
    required StyleSeed styleSeed,
    Duration? recordingDuration,
    String? speechText,
    ProgressCallback? onProgress,
  }) async {
    debugPrint('[AudioGenerator] === Pipeline start ===');
    debugPrint('[AudioGenerator] Input: $wavFilePath, style: ${styleSeed.label}'
        '${speechText != null ? ', speech: "$speechText"' : ''}');

    final stopwatch = Stopwatch()..start();
    int melodyNoteCount = 0;

    try {
      // ── Stage 1: Read WAV ──
      onProgress?.call(PipelineProgress.stages[0]);
      final samples = await AudioProcessor.readWav(wavFilePath);
      debugPrint('[AudioGenerator] Stage 1: Read ${samples.length} samples');

      // ── Stage 2: YIN pitch detection ──
      onProgress?.call(PipelineProgress.stages[1]);
      final pitchContour = AudioProcessor.detectPitch(samples, 44100);
      final voicedFrames = pitchContour.where((p) => p.frequencyHz > 0).length;
      final voicedRatio = pitchContour.isNotEmpty
          ? voicedFrames / pitchContour.length
          : 0.0;
      debugPrint('[AudioGenerator] Stage 2: YIN → ${pitchContour.length} frames, voiced ratio: ${(voicedRatio * 100).toStringAsFixed(0)}%');

      // ── Stage 3: MIDI quantization ──
      var melody = AudioProcessor.pitchToMidi(pitchContour);
      melodyNoteCount = melody.length;
      debugPrint('[AudioGenerator] Stage 3: Quantized → $melodyNoteCount MIDI notes');
      onProgress?.call(PipelineProgress(
        stageName: '找到音符了！',
        icon: '🎵',
        fraction: 0.38,
        detail: melodyNoteCount > 0
            ? '发现了 $melodyNoteCount 个音符'
            : (speechText != null ? '正在理解你说的话...' : '正在创作一段旋律...'),
      ));

      // Low voiced ratio + speech text = user was speaking, not humming
      final isSpeaking = speechText != null && (voicedRatio < 0.3 || melodyNoteCount < 3);

      // Fallback melody for silent/too-short recordings (or pure speech)
      if (melody.isEmpty || isSpeaking) {
        if (isSpeaking) {
          debugPrint('[AudioGenerator] Detected speech input, generating melody from text');
        } else {
          debugPrint('[AudioGenerator] No melody detected, generating fallback');
        }
        melody = _generateFallbackMelody(
          (recordingDuration?.inSeconds ?? 4).clamp(2, 10).toDouble(),
          seed: speechText ?? styleSeed.name,
        );
        melodyNoteCount = melody.length;
      }

      // ── Stage 4: AI full-score generation ──
      onProgress?.call(PipelineProgress.stages[3]);
      final totalDuration = melody.isNotEmpty
          ? (melody.map((n) => n.startSeconds + n.durationSeconds).reduce(max) + 1.0).clamp(3.0, 30.0)
          : (recordingDuration?.inSeconds ?? 4).clamp(3, 12).toDouble();
      final tonicMidi = _guessTonic(melody);

      Arrangement arrangement;
      String? aiMoodNote;
      bool aiEnhanced = false;
      final melodyData = melody.map((n) => {
        'noteNumber': n.noteNumber,
        'startSeconds': n.startSeconds,
        'durationSeconds': n.durationSeconds,
        'velocity': n.velocity,
      }).toList();

      try {
        final score = await DashScopeService().generateFullScore(
          melodyNotes: melodyData,
          totalDuration: totalDuration,
          tonicMidi: tonicMidi,
          speechText: speechText,
          needsMelody: isSpeaking,
        );

        if (score != null && score.bars.isNotEmpty) {
          arrangement = ArrangementEngine.arrangeFromAiScore(
            melody: melody,
            score: score,
            tonicMidi: tonicMidi,
            durationOverride: totalDuration,
          );
          aiMoodNote = score.mood;
          aiEnhanced = true;
          debugPrint('[AudioGenerator] Stage 4: AI full-score used (${score.bars.length} bars, mood: ${score.mood})');
        } else {
          arrangement = ArrangementEngine.arrange(melody: melody, style: styleSeed, durationOverride: totalDuration);
          debugPrint('[AudioGenerator] Stage 4: AI unavailable, using rule engine');
        }
      } catch (e) {
        arrangement = ArrangementEngine.arrange(melody: melody, style: styleSeed, durationOverride: totalDuration);
        debugPrint('[AudioGenerator] Stage 4: AI error ($e), using rule engine');
      }

      debugPrint('[AudioGenerator] Arranged: mel:${arrangement.melody.length} '
          'chd:${arrangement.chords.length} bass:${arrangement.bass.length} '
          'perc:${arrangement.percussion.length}');

      // ── Stage 5: WAV synthesis ──
      onProgress?.call(PipelineProgress.stages[4]);
      if (aiMoodNote != null && aiMoodNote.isNotEmpty) {
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
      await WavSynthesizerIsolate.renderToFile(
        arrangement: arrangement,
        style: styleSeed,
        outputPath: outputPath,
      );

      stopwatch.stop();
      debugPrint('[AudioGenerator] Synthesized → $outputPath '
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
        aiEnhanced: aiEnhanced,
        aiMoodNote: aiMoodNote,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AudioGenerator] Pipeline error (${stopwatch.elapsedMilliseconds}ms): $e');
      final fallbackPath = await _generateEmergencyPath(styleSeed: styleSeed.name);
      final fallbackMelody = _generateFallbackMelody((recordingDuration?.inSeconds ?? 4).clamp(2, 10).toDouble(), seed: 'emergency');
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

  static int _guessTonic(List<MidiNoteEvent> melody) {
    if (melody.isEmpty) return 60;
    final avg = melody.map((n) => n.noteNumber).reduce((a, b) => a + b) ~/ melody.length;
    return (avg ~/ 12) * 12 + (avg % 12);
  }

  /// Generate a varied fallback melody using pentatonic scale.
  ///
  /// Uses a simple hash of [seed] (e.g. speech text or duration) to pick
  /// different note sequences, so different inputs produce different melodies
  /// even when AI is unavailable.
  ///
  /// Builds phrase-structured melodies with varied rhythms (eighth, triplet,
  /// quarter, dotted, half), occasional rests, directional contour, and
  /// style-appropriate pentatonic scales.
  static List<MidiNoteEvent> _generateFallbackMelody(double durationSeconds, {String? seed}) {
    final rng = _simpleRng(seed ?? durationSeconds.toString());

    // Pick a pentatonic scale based on seed — C, G, F, or D pentatonic
    const scales = [
      [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84], // C pentatonic
      [55, 59, 62, 67, 69, 71, 74, 76, 79, 83, 86], // G pentatonic
      [53, 57, 60, 65, 67, 69, 72, 74, 77, 81, 84], // F pentatonic
      [57, 59, 62, 66, 69, 71, 74, 78, 81, 83, 86], // D pentatonic
    ];
    final pentatonic = scales[rng.next() % scales.length];

    // Rhythmic values (in seconds at ~120bpm feel)
    const rhythms = [
      0.25, // eighth note
      0.25,
      0.25,
      0.33, // triplet
      0.33,
      0.5,  // quarter note
      0.5,
      0.5,
      0.5,
      0.75, // dotted quarter
      1.0,  // half note
    ];

    final notes = <MidiNoteEvent>[];
    var time = 0.0;
    var lastIdx = pentatonic.length ~/ 2;
    var notesInPhrase = 0;
    // Phrase length: 3-6 notes before a rest
    final phraseLen = 3 + (rng.next() % 4);
    // Overall contour direction for this phrase: +1 rising, -1 falling, 0 arch
    var contourDir = (rng.next() % 3) - 1;
    var contourSteps = 0;

    while (time < durationSeconds) {
      // ── Phrase break: insert a rest every phraseLen notes ──
      if (notesInPhrase >= phraseLen && notes.isNotEmpty) {
        final restDur = rhythms[rng.next() % 4]; // 0.25-0.5 rest
        time += restDur;
        notesInPhrase = 0;
        // New phrase: reset contour direction, re-center position
        contourDir = (rng.next() % 3) - 1;
        contourSteps = 0;
        // Tend to return toward mid-range
        final mid = pentatonic.length ~/ 2;
        if ((lastIdx - mid).abs() > 2) {
          lastIdx = (lastIdx + (mid > lastIdx ? 1 : -1)).clamp(0, pentatonic.length - 1);
        }
        if (time >= durationSeconds) break;
      }

      // ── Choose step size ──
      final stepRoll = rng.next() % 10;
      int step;
      if (stepRoll < 5) {
        step = contourDir; // follow phrase contour
      } else if (stepRoll < 8) {
        step = (rng.next() % 5) - 2; // small random walk
      } else {
        step = (rng.next() % 7) - 3; // occasional leap
      }
      contourSteps++;

      // Reverse contour direction occasionally
      if (contourSteps > 4) {
        contourDir = -contourDir;
        contourSteps = 0;
      }

      lastIdx = (lastIdx + step).clamp(0, pentatonic.length - 1);

      // ── Choose duration ──
      final dur = rhythms[rng.next() % rhythms.length];
      final noteEnd = time + dur;
      if (noteEnd > durationSeconds) {
        // Final note: fill remaining time
        final remaining = durationSeconds - time;
        if (remaining < 0.15) break;
        notes.add(MidiNoteEvent(
          noteNumber: pentatonic[lastIdx],
          startSeconds: time,
          durationSeconds: remaining * 0.85,
          velocity: 0.5 + (rng.next() % 35) / 100.0,
        ));
        break;
      }

      notes.add(MidiNoteEvent(
        noteNumber: pentatonic[lastIdx],
        startSeconds: time,
        durationSeconds: dur * 0.82,
        velocity: 0.45 + (rng.next() % 40) / 100.0,
      ));
      time += dur;
      notesInPhrase++;
    }

    return notes;
  }

  /// Trivial LCG for deterministic pseudo-random numbers.
  static _SimpleRng _simpleRng(String seed) {
    var h = 0;
    for (var i = 0; i < seed.length; i++) {
      h = (h * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return _SimpleRng(h);
  }

  static Future<String> _generateEmergencyPath({
    required String styleSeed,
    double durationSec = 3.0,
  }) async {
    const sampleRate = 44100;

    // Pentatonic scale frequencies based on style
    double baseFreq;
    switch (styleSeed) {
      case 'morningDew': baseFreq = 523.25; break; // C5
      case 'mountainStream': baseFreq = 329.63; break; // E4
      case 'frogDrum': baseFreq = 440.0; break; // A4
      default: baseFreq = 440.0;
    }
    // Build a 2-octave pentatonic scale (freq ratios: 1, 9/8, 5/4, 3/2, 5/3, 2)
    final pentRatios = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0, 2.25, 2.5, 3.0, 3.334];
    final pentFreqs = pentRatios.map((r) => baseFreq * r).toList();

    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);

    // Walk pentatonic scale with melody-like contour
    final rng = _simpleRng(styleSeed);
    var noteIdx = pentFreqs.length ~/ 3; // start lower-mid
    var contourDir = 1;
    var contourSteps = 0;
    var samplePos = 0;

    while (samplePos < numSamples) {
      // Note duration: 0.2-0.6 seconds
      final noteLenSamples = ((0.2 + (rng.next() % 5) * 0.1) * sampleRate).round();
      final noteEnd = (samplePos + noteLenSamples).clamp(0, numSamples);
      final freq = pentFreqs[noteIdx];

      // Walk contour
      contourSteps++;
      if (contourSteps > 3) {
        contourDir = -contourDir;
        contourSteps = 0;
      }
      final step = contourDir;
      noteIdx = (noteIdx + step).clamp(0, pentFreqs.length - 1);

      final noteDuration = noteEnd - samplePos;

      for (var i = samplePos; i < noteEnd; i++) {
        final t = (i - samplePos) / sampleRate;
        final totalDuration = noteDuration / sampleRate;

        // ADSR envelope
        double env;
        if (t < 0.02) {
          env = t / 0.02; // attack
        } else if (t < totalDuration - 0.08) {
          env = 0.85; // sustain (slight decay from 1.0 peak)
        } else {
          env = 0.85 * (1.0 - (t - (totalDuration - 0.08)) / 0.08); // release
        }

        // Fundamental + 2 harmonics for richer tone
        final fundamental = sin(2 * pi * freq * i / sampleRate);
        final harmonic2 = sin(2 * pi * freq * 2 * i / sampleRate) * 0.15;
        final harmonic3 = sin(2 * pi * freq * 3 * i / sampleRate) * 0.06;

        samples[i] += (fundamental + harmonic2 + harmonic3) * env * 0.5;
      }

      samplePos = noteEnd;
    }

    // Global fade in/out
    final fadeLen = (0.05 * sampleRate).round();
    for (var i = 0; i < fadeLen && i < numSamples; i++) {
      samples[i] *= i / fadeLen;
      samples[numSamples - 1 - i] *= i / fadeLen;
    }

    final outPath = FileStorageService().generateMusicPath(styleSeed: styleSeed, extension: 'wav');
    await AudioProcessor.writeWav(outPath, samples, sampleRate);
    return outPath;
  }
}

/// Simple LCG-based pseudo-random number generator.
class _SimpleRng {
  int _state;
  _SimpleRng(this._state);

  int next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state;
  }
}
