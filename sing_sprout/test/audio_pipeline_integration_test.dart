import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_sprout/shared/services/audio_processor.dart';
import 'package:sing_sprout/shared/services/arrangement_engine.dart';
import 'package:sing_sprout/shared/services/wav_synthesizer.dart';
import 'package:sing_sprout/core/constants/enums.dart';

void main() {
  test('full pipeline: WAV -> YIN -> MIDI -> arrangement -> WAV render', () async {
    // 1. Generate a test WAV file (sine wave at 440Hz = A4, 1 second)
    final testWavPath = '${Directory.systemTemp.path}/test_humming.wav';
    const sampleRate = 44100;
    final samples = Float64List(sampleRate); // 1 second
    for (var i = 0; i < samples.length; i++) {
      final t = i / sampleRate;
      // 440Hz sine, 80% duty (0.8s on), gentle fade in/out
      final envelope = (t < 0.1 ? t / 0.1 : (t > 0.8 ? (1.0 - (t - 0.8) / 0.2) : 1.0)).clamp(0.0, 1.0);
      samples[i] = 0.5 * envelope * sin(2 * pi * 440 * t);
    }
    await AudioProcessor.writeWav(testWavPath, samples, sampleRate);

    // 2. Read back and verify
    final readSamples = await AudioProcessor.readWav(testWavPath);
    expect(readSamples.length, equals(samples.length));

    // 3. Pitch detection
    final pitchContour = AudioProcessor.detectPitch(readSamples, sampleRate);
    expect(pitchContour, isNotEmpty);
    final voicedFrames = pitchContour.where((p) => p.frequencyHz > 0).length;
    expect(voicedFrames, greaterThan(0));

    // 4. MIDI quantization
    final melody = AudioProcessor.pitchToMidi(pitchContour);
    expect(melody, isNotEmpty);

    // 5. Arrangement
    final arrangement = ArrangementEngine.arrange(
      melody: melody,
      style: StyleSeed.morningDew,
    );
    expect(arrangement.melody, isNotEmpty);
    expect(arrangement.chords, isNotEmpty);

    // 6. WAV synthesis
    final outputPath = '${Directory.systemTemp.path}/test_output.wav';
    await WavSynthesizer.renderToFile(
      arrangementOrNotes: arrangement,
      style: StyleSeed.morningDew,
      outputPath: outputPath,
    );
    expect(await File(outputPath).exists(), isTrue);
    final outputFile = await File(outputPath).length();
    expect(outputFile, greaterThan(1000));

    // Cleanup
    await File(testWavPath).delete();
    await File(outputPath).delete();
  });
}