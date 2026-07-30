import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_sprout/shared/services/audio_processor.dart';
import 'package:sing_sprout/shared/services/pitch_detection_service.dart';

/// A/B comparison utility for pitch detection algorithms.
///
/// Generates synthetic test signals and compares Basic Pitch vs YIN accuracy,
/// voiced-frame agreement, and latency. Includes child-humming-specific
/// test cases (portamento, vibrato, phrase structure).
///
/// Run with:
///   flutter test test/pitch_detection_ab_test.dart

class PitchABComparison {
  final List<TestCase> _results = [];

  static Future<void> runStandardSuite() async {
    final comp = PitchABComparison();

    // ── Pure tones (child vocal range: 200–600 Hz) ──
    const childFreqs = [196.0, 261.6, 329.6, 392.0, 440.0, 523.3, 587.3, 659.3];
    for (final freq in childFreqs) {
      comp.addResult(await comp._testPureTone(freq, sampleRate: 44100));
    }

    // ── Child-humming-specific tests ──
    comp.addResult(await comp._testPortamento(sampleRate: 44100));
    comp.addResult(await comp._testVibrato(sampleRate: 44100));
    comp.addResult(await comp._testChildPhrase(sampleRate: 44100));
    comp.addResult(await comp._testNoisyHumming(sampleRate: 44100));

    // ── Standard tests ──
    comp.addResult(await comp._testSweep(sampleRate: 44100));
    comp.addResult(await comp._testNoisyTone(261.6, sampleRate: 44100));

    comp._printSummary();
  }

  static Future<void> runOnFile(String wavPath) async {
    final comp = PitchABComparison();
    final result = await comp._testWavFile(wavPath);
    if (result != null) {
      comp.addResult(result);
      comp._printSummary();
    }
  }

  void addResult(TestCase result) => _results.add(result);

  // ── Pure tone ──

  Future<TestCase> _testPureTone(double freqHz, {int sampleRate = 44100}) async {
    const durationSec = 2.0;
    final samples = _generateSine(freqHz, sampleRate, durationSec);
    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Pure ${freqHz.toStringAsFixed(0)}Hz',
      groundTruthHz: freqHz,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Portamento (pitch slide between notes, typical of children) ──

  Future<TestCase> _testPortamento({int sampleRate = 44100}) async {
    const durationSec = 3.0;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    final rng = Random(42);

    // Slide through a child-like melody contour: C4→E4→G4→E4→C4
    const contour = [
      (0.0, 261.6),
      (0.6, 329.6),
      (1.2, 392.0),
      (1.8, 329.6),
      (2.4, 261.6),
      (3.0, 261.6),
    ];

    var phase = 0.0;
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Find current segment and interpolate frequency
      double freq = contour[0].$2;
      var segEnd = 0;
      for (var s = 0; s < contour.length - 1; s++) {
        if (t >= contour[s].$1 && t < contour[s + 1].$1) {
          final segFrac = (t - contour[s].$1) /
              (contour[s + 1].$1 - contour[s].$1);
          // Smooth ease-in-out between notes (portamento)
          final smoothFrac = segFrac < 0.15
              ? 0.0
              : (segFrac - 0.15) / 0.7; // 15% slide, then sustain
          freq = contour[s].$2 +
              (contour[s + 1].$2 - contour[s].$2) * smoothFrac.clamp(0.0, 1.0);
          segEnd = 1;
          break;
        }
      }
      if (segEnd == 0) {
        freq = contour.last.$2;
      }
      freq = freq.clamp(200.0, 700.0);

      // Slight volume variation
      final envelope = 0.35 + 0.1 * sin(2 * pi * 3.0 * t);
      // Add breath noise
      final noise = (rng.nextDouble() - 0.5) * 0.02;

      phase += 2 * pi * freq / sampleRate;
      samples[i] = envelope * sin(phase) + noise;
    }

    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Portamento C→E→G→E→C (child slide)',
      groundTruthHz: null,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Vibrato (pitch oscillation, 5-7 Hz typical of children) ──

  Future<TestCase> _testVibrato({int sampleRate = 44100}) async {
    const durationSec = 2.0;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    const centerFreq = 330.0;
    const vibratoRate = 5.5; // Hz
    const vibratoDepth = 12.0; // Hz (±12 Hz = ~63 cents)

    var phase = 0.0;
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final freq = centerFreq + vibratoDepth * sin(2 * pi * vibratoRate * t);
      final envelope = 0.4 * (0.9 + 0.1 * sin(2 * pi * 2.0 * t));
      phase += 2 * pi * freq / sampleRate;
      samples[i] = envelope * sin(phase);
    }

    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Vibrato ${centerFreq.toStringAsFixed(0)}Hz ±${vibratoDepth.toStringAsFixed(0)}Hz',
      groundTruthHz: centerFreq,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Child phrase (short melody with breath pauses) ──

  Future<TestCase> _testChildPhrase({int sampleRate = 44100}) async {
    const durationSec = 4.0;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    final rng = Random(99);

    // "Twinkle twinkle" phrase: C C G G A A G — rest — F F E E D D C
    final notes = [
      (0.00, 261.6), (0.40, 261.6), (0.80, 392.0), (1.20, 392.0),
      (1.60, 440.0), (2.00, 440.0), (2.40, 392.0),
      // breath rest at ~2.8-3.0
      (3.00, 349.2), (3.30, 349.2), (3.60, 329.6), (3.80, 329.6),
      (4.00, 293.7), (4.20, 293.7), (4.40, 261.6),
    ];

    var phase = 0.0;
    var currentNote = 0;
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Find current note
      while (currentNote < notes.length - 1 && t >= notes[currentNote + 1].$1) {
        currentNote++;
      }

      if (t >= notes[currentNote].$1) {
        final noteStart = notes[currentNote].$1;
        final noteElapsed = t - noteStart;

        // Breath pause between phrases
        final isBreath = t > 2.6 && t < 3.0;
        if (isBreath) {
          samples[i] = (rng.nextDouble() - 0.5) * 0.01; // near-silence
          continue;
        }

        // Note attack envelope
        const attackTime = 0.04;
        const sustainLevel = 0.35;
        final envelope = noteElapsed < attackTime
            ? (noteElapsed / attackTime) * sustainLevel
            : sustainLevel * (0.9 + 0.1 * sin(2 * pi * 2.5 * t));

        final freq = notes[currentNote].$2;
        phase += 2 * pi * freq / sampleRate;
        final noise = (rng.nextDouble() - 0.5) * 0.015;
        samples[i] = envelope * sin(phase) + noise;
      }
    }

    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Child phrase (Twinkle melody + breath rest)',
      groundTruthHz: null,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Noisy humming (simulates real-world room recording) ──

  Future<TestCase> _testNoisyHumming({int sampleRate = 44100}) async {
    const durationSec = 2.5;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    final rng = Random(123);

    const freq = 330.0;
    var phase = 0.0;

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Humming envelope: slow attack + vibrato-like amplitude modulation
      final envelope = 0.25 *
          (0.8 + 0.2 * sin(2 * pi * 4.5 * t)) *
          (t < 0.15 ? t / 0.15 : 1.0) *
          (t > durationSec - 0.2 ? (durationSec - t) / 0.2 : 1.0);

      // Room tone (~-30dB)
      final roomNoise = (rng.nextDouble() - 0.5) * 0.03;

      // Occasional click/pop
      final click = (rng.nextDouble() < 0.002) ? (rng.nextDouble() - 0.5) * 0.2 : 0.0;

      // Low-frequency rumble (fridge/AC at 60Hz)
      final rumble = 0.01 * sin(2 * pi * 60 * t);

      phase += 2 * pi * freq / sampleRate;
      samples[i] = envelope * sin(phase) + roomNoise + click + rumble;
    }

    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Noisy humming 330Hz (room tone, clicks, rumble)',
      groundTruthHz: 330.0,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Sweep ──

  Future<TestCase> _testSweep({int sampleRate = 44100}) async {
    const durationSec = 3.0;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final freq = 150.0 + 500.0 * t / durationSec;
      samples[i] = 0.5 * sin(2 * pi * freq * t);
    }
    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Sweep 150→650Hz',
      groundTruthHz: null,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── Noisy tone ──

  Future<TestCase> _testNoisyTone(double freqHz, {int sampleRate = 44100}) async {
    const durationSec = 2.0;
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    final rng = Random(42);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final signal = 0.3 * sin(2 * pi * freqHz * t);
      final noise = (rng.nextDouble() - 0.5) * 0.15;
      samples[i] = (signal + noise).clamp(-1.0, 1.0);
    }
    final yinResult = await _benchmark(samples, sampleRate, 'YIN');
    final bpResult = await _benchmark(samples, sampleRate, 'BasicPitch');
    return TestCase(
      name: 'Noisy ${freqHz.toStringAsFixed(0)}Hz (SNR ~6dB)',
      groundTruthHz: freqHz,
      yin: yinResult,
      basicPitch: bpResult,
    );
  }

  // ── WAV file ──

  Future<TestCase?> _testWavFile(String path) async {
    try {
      final samples = await AudioProcessor.readWav(path);
      final yinResult = await _benchmark(samples, 44100, 'YIN');
      final bpResult = await _benchmark(samples, 44100, 'BasicPitch');
      return TestCase(
        name: path.split('/').last,
        groundTruthHz: null,
        yin: yinResult,
        basicPitch: bpResult,
      );
    } catch (e) {
      print('Error reading WAV: $e');
      return null;
    }
  }

  // ── Benchmark ──

  Future<BenchmarkResult> _benchmark(
    Float64List samples,
    int sampleRate,
    String algorithm,
  ) async {
    if (algorithm == 'BasicPitch') {
      final pd = PitchDetectionService();
      if (!pd.isAvailable) {
        return BenchmarkResult(
          algorithm: algorithm,
          latencyMs: -1,
          frameCount: 0,
          voicedRatio: 0,
          medianFreqHz: null,
          note: 'TFLite model not loaded',
        );
      }

      final sw = Stopwatch()..start();
      final contour = await pd.detectPitch(samples, sampleRate);
      sw.stop();

      return _buildResult(algorithm, contour, sw.elapsedMilliseconds);
    } else {
      // YIN
      final sw = Stopwatch()..start();
      final contour = AudioProcessor.detectPitch(samples, sampleRate);
      sw.stop();

      return _buildResult(algorithm, contour, sw.elapsedMilliseconds);
    }
  }

  BenchmarkResult _buildResult(
    String algorithm,
    List<PitchPoint> contour,
    int latencyMs,
  ) {
    final voicedFrames = contour.where((p) => p.frequencyHz > 0).length;
    final voicedRatio = contour.isNotEmpty ? voicedFrames / contour.length : 0.0;
    final medianFreq = _median(
      contour.where((p) => p.frequencyHz > 0).map((p) => p.frequencyHz).toList(),
    );
    return BenchmarkResult(
      algorithm: algorithm,
      latencyMs: latencyMs,
      frameCount: contour.length,
      voicedRatio: voicedRatio,
      medianFreqHz: medianFreq,
    );
  }

  // ── Reporting ──

  void _printSummary() {
    print('\n═══════════════════════════════════════════════════════════════');
    print('  Pitch Detection A/B: Basic Pitch vs YIN');
    print('  (Includes child-humming test signals)');
    print('═══════════════════════════════════════════════════════════════\n');

    for (final tc in _results) {
      print('── ${tc.name} ──');
      if (tc.groundTruthHz != null) {
        print('  Ground truth: ${tc.groundTruthHz!.toStringAsFixed(0)} Hz');
      }

      for (final r in [tc.yin, tc.basicPitch]) {
        final freqStr = r.medianFreqHz != null
            ? '${r.medianFreqHz!.toStringAsFixed(1)} Hz'
            : 'N/A';
        final latencyStr = r.latencyMs >= 0 ? '${r.latencyMs}ms' : (r.note ?? 'N/A');
        final voicedStr = '${(r.voicedRatio * 100).toStringAsFixed(0)}% voiced';
        final frameStr = '${r.frameCount} frames';
        print('  ${r.algorithm.padRight(11)} | $freqStr | $voicedStr | $frameStr | $latencyStr');
      }

      // Compare if both ran
      if (tc.yin.medianFreqHz != null && tc.basicPitch.medianFreqHz != null) {
        final diffCents = (1200 * log(tc.basicPitch.medianFreqHz! / tc.yin.medianFreqHz!) / ln2)
            .abs();
        print('  Pitch diff: ${diffCents.toStringAsFixed(1)} cents');
      }

      if (tc.yin.frameCount > 0 && tc.basicPitch.frameCount > 0) {
        final agreement = (1.0 - (tc.yin.voicedRatio - tc.basicPitch.voicedRatio).abs())
            .clamp(0.0, 1.0);
        print('  Voiced agreement: ${(agreement * 100).toStringAsFixed(0)}%');
      }

      print('');
    }
    print('═══════════════════════════════════════════════════════════════\n');
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length % 2 == 0
        ? (sorted[mid - 1] + sorted[mid]) / 2
        : sorted[mid];
  }

  static Float64List _generateSine(double freqHz, int sampleRate, double durationSec) {
    final numSamples = (sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fadeLen = (0.05 * sampleRate).round();
      var envelope = 1.0;
      if (i < fadeLen) envelope = i / fadeLen;
      if (i > numSamples - fadeLen) envelope = (numSamples - i) / fadeLen;
      samples[i] = 0.5 * envelope * sin(2 * pi * freqHz * t);
    }
    return samples;
  }
}

class BenchmarkResult {
  final String algorithm;
  final int latencyMs;
  final int frameCount;
  final double voicedRatio;
  final double? medianFreqHz;
  final String? note;

  const BenchmarkResult({
    required this.algorithm,
    required this.latencyMs,
    required this.frameCount,
    required this.voicedRatio,
    this.medianFreqHz,
    this.note,
  });
}

class TestCase {
  final String name;
  final double? groundTruthHz;
  final BenchmarkResult yin;
  final BenchmarkResult basicPitch;

  const TestCase({
    required this.name,
    this.groundTruthHz,
    required this.yin,
    required this.basicPitch,
  });
}

void main() {
  test('A/B: Basic Pitch vs YIN on child-humming test tones', () async {
    await PitchABComparison.runStandardSuite();
  });
}
