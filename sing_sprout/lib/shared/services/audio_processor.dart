import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// YIN pitch detection result at a point in time.
class PitchPoint {
  final double timeSeconds;
  final double frequencyHz; // 0.0 = silence/unvoiced
  const PitchPoint(this.timeSeconds, this.frequencyHz);
}

/// MIDI note representation used throughout the pipeline.
class MidiNoteEvent {
  final int noteNumber; // 0-127 MIDI, -1 = rest
  final double startSeconds;
  final double durationSeconds;
  final double velocity; // 0.0-1.0
  const MidiNoteEvent({
    required this.noteNumber,
    required this.startSeconds,
    required this.durationSeconds,
    this.velocity = 0.8,
  });

  Map<String, dynamic> toMap() => {
    'n': noteNumber,
    's': startSeconds,
    'd': durationSeconds,
    'v': velocity,
  };

  factory MidiNoteEvent.fromMap(Map<String, dynamic> m) => MidiNoteEvent(
    noteNumber: m['n'] as int,
    startSeconds: (m['s'] as num).toDouble(),
    durationSeconds: (m['d'] as num).toDouble(),
    velocity: (m['v'] as num).toDouble(),
  );
}

/// Pure-Dart audio analysis: WAV reading, YIN pitch detection, silence gating.
///
/// Zero external dependencies. Works fully offline on any device.
/// Core requirement per optimization plan: 0MB model for DSP stage.
class AudioProcessor {
  // ── WAV I/O ──

  /// Read a 16-bit mono WAV file, return normalized [-1.0, 1.0] samples.
  static Future<Float64List> readWav(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return _parseWav(bytes);
  }

  static Float64List _parseWav(Uint8List bytes) {
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    // Skip RIFF header, find 'data' chunk
    var offset = 12;
    int dataSize = 0;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        dataSize = chunkSize;
        offset += 8;
        break;
      }
      offset += 8 + chunkSize;
    }
    if (dataSize == 0) return Float64List(0);

    final numSamples = dataSize ~/ 2; // 16-bit = 2 bytes per sample
    final samples = Float64List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final sample = data.getInt16(offset + i * 2, Endian.little);
      samples[i] = sample / 32768.0;
    }
    return samples;
  }

  /// Write normalized samples as a 16-bit mono WAV file.
  static Future<void> writeWav(String filePath, Float64List samples, int sampleRate) async {
    final dataSize = samples.length * 2;
    final fileSize = 44 + dataSize;
    final out = ByteData(fileSize);

    void w(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        out.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    w(0, 'RIFF');
    out.setUint32(4, fileSize - 8, Endian.little);
    w(8, 'WAVE');
    w(12, 'fmt ');
    out.setUint32(16, 16, Endian.little); // PCM
    out.setUint16(20, 1, Endian.little); // format = 1
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    out.setUint16(32, 2, Endian.little); // block align
    out.setUint16(34, 16, Endian.little); // bits per sample
    w(36, 'data');
    out.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      out.setInt16(44 + i * 2, v, Endian.little);
    }

    await File(filePath).writeAsBytes(out.buffer.asUint8List());
  }

  // ── YIN Pitch Detection ──

  /// Run YIN algorithm on samples, return pitch contour.
  ///
  /// [windowSize] controls frequency resolution vs time resolution.
  /// [hopSize] controls output density.
  /// [threshold] is the YIN aperiodicity threshold (lower = stricter).
  ///
  /// Frequency range: ~80Hz (adult lower) to ~1000Hz (child upper).
  static List<PitchPoint> detectPitch(
    Float64List samples,
    int sampleRate, {
    int windowSize = 1024,   // low-end optimized
    int hopSize = 512,
    double threshold = 0.15,
    double silenceRms = 0.01,
    int? minTau,
    int? maxTau,
  }) {
    if (samples.length < windowSize) return [];

    // Auto-range: 100Hz–1000Hz (children hum ~200–600Hz)
    final effectiveMinTau = minTau ?? (sampleRate ~/ 1000).clamp(20, 100);
    final effectiveMaxTau = maxTau ?? (sampleRate ~/ 100).clamp(100, 600);

    final numWindows = (samples.length - windowSize) ~/ hopSize + 1;
    final results = <PitchPoint>[];

    final diffBuf = Float64List(effectiveMaxTau + 1);
    final cmndBuf = Float64List(effectiveMaxTau + 1);

    for (var w = 0; w < numWindows; w++) {
      final offset = w * hopSize;
      final time = offset / sampleRate;

      // Compute RMS for silence detection
      var rms = 0.0;
      for (var j = 0; j < windowSize; j++) {
        rms += samples[offset + j] * samples[offset + j];
      }
      rms = sqrt(rms / windowSize);
      if (rms < silenceRms) {
        results.add(PitchPoint(time, 0.0));
        continue;
      }

      // YIN difference function
      for (var tau = 0; tau <= effectiveMaxTau; tau++) {
        var d = 0.0;
        for (var j = 0; j < windowSize; j++) {
          final diff = samples[offset + j] - samples[(offset + j + tau).clamp(0, samples.length - 1)];
          d += diff * diff;
        }
        diffBuf[tau] = d;
      }

      // Cumulative mean normalized difference
      cmndBuf[0] = 1.0;
      var runningSum = 0.0;
      for (var tau = 1; tau <= effectiveMaxTau; tau++) {
        runningSum += diffBuf[tau];
        cmndBuf[tau] = diffBuf[tau] * tau / (runningSum + 1e-12);
      }

      // Find first dip below threshold
      int tauEstimate = -1;
      for (var tau = effectiveMinTau; tau < effectiveMaxTau; tau++) {
        if (cmndBuf[tau] < threshold) {
          // Check it's a local minimum
          if (cmndBuf[tau] < cmndBuf[tau - 1] && cmndBuf[tau] < cmndBuf[tau + 1]) {
            tauEstimate = tau;
            break;
          }
        }
      }

      if (tauEstimate < 0) {
        // No clear pitch — find absolute minimum in range
        var minVal = double.infinity;
        for (var tau = effectiveMinTau; tau < effectiveMaxTau; tau++) {
          if (cmndBuf[tau] < minVal) {
            minVal = cmndBuf[tau];
            tauEstimate = tau;
          }
        }
        if (minVal > 0.5) {
          results.add(PitchPoint(time, 0.0)); // too aperiodic, treat as unvoiced
          continue;
        }
      }

      // Parabolic interpolation for sub-sample accuracy
      final t0 = tauEstimate - 1;
      final t1 = tauEstimate;
      final t2 = tauEstimate + 1;
      final d0 = cmndBuf[t0.clamp(0, effectiveMaxTau)];
      final d1 = cmndBuf[t1];
      final d2 = cmndBuf[t2.clamp(0, effectiveMaxTau)];
      final betterTau = tauEstimate + (d2 - d0) / (2 * (2 * d1 - d0 - d2) + 1e-12);

      final freq = sampleRate / betterTau;
      // Clamp to reasonable range
      if (freq >= 65 && freq <= 1200) {
        results.add(PitchPoint(time, freq));
      } else {
        results.add(PitchPoint(time, 0.0));
      }
    }

    return results;
  }

  // ── Pitch→MIDI Quantization ──

  /// Convert pitch contour to MIDI note events.
  ///
  /// Adjacent frames with the same note are merged into sustained notes.
  /// Silences become rests (noteNumber = -1).
  static List<MidiNoteEvent> pitchToMidi(List<PitchPoint> pitchContour, {
    double minNoteDuration = 0.08, // ignore notes shorter than 80ms
    int minMidiNote = 48,  // C3
    int maxMidiNote = 84,  // C6
  }) {
    if (pitchContour.isEmpty) return [];

    // Convert each frame to MIDI note number
    final midiFrames = <_MidiFrame>[];
    for (final pp in pitchContour) {
      int note;
      if (pp.frequencyHz <= 0) {
        note = -1; // rest
      } else {
        note = (12 * (log(pp.frequencyHz / 440) / ln2) + 69).round();
        note = note.clamp(minMidiNote, maxMidiNote);
      }
      midiFrames.add(_MidiFrame(pp.timeSeconds, note));
    }

    // Merge consecutive same-note frames into events
    final events = <MidiNoteEvent>[];
    if (midiFrames.isEmpty) return events;

    var startTime = midiFrames[0].time;
    var currentNote = midiFrames[0].note;

    for (var i = 1; i < midiFrames.length; i++) {
      if (midiFrames[i].note != currentNote) {
        final duration = midiFrames[i].time - startTime;
        if (currentNote >= 0 && duration >= minNoteDuration) {
          events.add(MidiNoteEvent(
            noteNumber: currentNote,
            startSeconds: startTime,
            durationSeconds: duration,
          ),);
        }
        startTime = midiFrames[i].time;
        currentNote = midiFrames[i].note;
      }
    }

    // Last note
    final lastDuration = midiFrames.last.time - startTime;
    if (currentNote >= 0 && lastDuration >= minNoteDuration) {
      events.add(MidiNoteEvent(
        noteNumber: currentNote,
        startSeconds: startTime,
        durationSeconds: lastDuration.clamp(0.05, 2.0),
      ),);
    }

    return events;
  }

  /// Compute the total RMS energy of a signal (for silence detection).
  static double rms(Float64List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return sqrt(sum / samples.length);
  }
}

class _MidiFrame {
  final double time;
  final int note; // -1 = rest
  const _MidiFrame(this.time, this.note);
}
