import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'audio_processor.dart';
import 'device_capability_service.dart';

/// On-device pitch detection using Basic Pitch TFLite with YIN fallback.
///
/// Device-tiered: 1-2GB RAM → YIN only (DSP, 0MB); 2GB+ → Basic Pitch TFLite
/// (~0.84MB, CQT front-end, polyphonic capable) with YIN fallback.
///
/// Basic Pitch model from litert-community/Basic-Pitch-LiteRT (HuggingFace).
///   Input:  [1, 43844] float32  — ~2 s of 22050 Hz mono audio
///   Output: contour [1,172,264], note [1,172,88], onset [1,172,88]
///   Frame rate: ~11.6 ms (256-sample hop at 22050 Hz)
class PitchDetectionService {
  static final PitchDetectionService _instance = PitchDetectionService._();
  factory PitchDetectionService() => _instance;
  PitchDetectionService._();

  Interpreter? _interpreter;
  bool _modelLoaded = false;
  bool _aiEnabled = false;

  // Basic Pitch constants
  static const int _targetSampleRate = 22050;
  static const int _windowSamples = 43844;
  static const int _overlapSamples = 7680;
  static const int _hopSamples = _windowSamples - _overlapSamples;
  static const int _numFrames = 172;
  static const int _numMidiBins = 88;
  static const int _midiOffset = 21;

  /// Initialize TFLite model from assets. Call once at app startup.
  ///
  /// On low-end devices (<2GB RAM) this skips TFLite loading to avoid OOM.
  Future<void> initialize() async {
    final caps = DeviceCapabilityService();
    if (!caps.shouldUseAIPitchDetection) {
      debugPrint('[PitchDetection] Low-end device (${caps.totalRamMB}MB), using YIN only');
      _aiEnabled = false;
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/basicpitch.tflite');
      _modelLoaded = true;
      _aiEnabled = true;
      debugPrint('[PitchDetection] Basic Pitch TFLite loaded (device: ${caps.totalRamMB}MB)');
    } catch (e) {
      debugPrint('[PitchDetection] TFLite not available, using YIN fallback: $e');
      _modelLoaded = false;
      _aiEnabled = false;
    }
  }

  bool get isAvailable => _modelLoaded;
  bool get isAIEnabled => _aiEnabled;

  /// Detect pitch contour from audio samples.
  ///
  /// [samples] — normalized [-1.0, 1.0] audio samples at [sampleRate] Hz.
  /// Returns (timeSeconds, frequencyHz) pairs. frequencyHz = 0 means unvoiced.
  Future<List<PitchPoint>> detectPitch(
    Float64List samples,
    int sampleRate, {
    bool preferTflite = true,
  }) async {
    if (preferTflite && _modelLoaded) {
      try {
        return await _detectWithBasicPitch(samples, sampleRate);
      } catch (e) {
        debugPrint('[PitchDetection] Basic Pitch failed, falling back to YIN: $e');
      }
    }
    return _detectWithYin(samples, sampleRate);
  }

  /// Basic Pitch TFLite inference.
  ///
  /// Resamples to 22050 Hz, processes in 2-second overlapping windows,
  /// extracts dominant pitch per frame from the note-activation output.
  Future<List<PitchPoint>> _detectWithBasicPitch(
    Float64List samples,
    int sampleRate,
  ) async {
    // Resample to 22050 Hz if needed
    Float64List audio;
    if (sampleRate == _targetSampleRate) {
      audio = samples;
    } else {
      audio = _resample(samples, sampleRate, _targetSampleRate);
    }

    final results = <PitchPoint>[];

    for (var offset = 0; offset + _windowSamples <= audio.length; offset += _hopSamples) {
      // Build input tensor [1, 43844]
      final input = Float32List(_windowSamples);
      for (var i = 0; i < _windowSamples; i++) {
        input[i] = audio[offset + i].toDouble();
      }
      final inputTensor = [input];

      // Allocate output tensors
      final contourOutput = [
        List.generate(_numFrames, (_) => Float32List(264)),
      ];
      final noteOutput = [
        List.generate(_numFrames, (_) => Float32List(_numMidiBins)),
      ];
      final onsetOutput = [
        List.generate(_numFrames, (_) => Float32List(_numMidiBins)),
      ];

      _interpreter!.runForMultipleInputs([inputTensor], {
        0: contourOutput,
        1: noteOutput,
        2: onsetOutput,
      });

      // Extract pitch from note activations
      final isLastWindow = offset + _windowSamples >= audio.length;
      final framesToKeep = isLastWindow
          ? _numFrames
          : (_hopSamples ~/ 256).clamp(0, _numFrames);

      for (var f = 0; f < framesToKeep; f++) {
        final timeSec = (offset / _targetSampleRate) + (f * 256 / _targetSampleRate);

        // Find max activation across all 88 MIDI bins
        var maxVal = 0.0;
        var maxBin = -1;
        for (var b = 0; b < _numMidiBins; b++) {
          if (noteOutput[0][f][b] > maxVal) {
            maxVal = noteOutput[0][f][b];
            maxBin = b;
          }
        }

        if (maxVal > 0.5 && maxBin >= 0) {
          final midiNote = maxBin + _midiOffset;
          final freqHz = 440.0 * pow(2.0, (midiNote - 69) / 12.0);
          results.add(PitchPoint(timeSec, freqHz));
        } else {
          results.add(PitchPoint(timeSec, 0.0));
        }
      }

    }

    return results;
  }

  /// Simple linear resampling.
  Float64List _resample(Float64List samples, int fromRate, int toRate) {
    if (fromRate == toRate) return samples;

    final ratio = fromRate / toRate;
    final outLen = (samples.length / ratio).round();
    final out = Float64List(outLen);

    for (var i = 0; i < outLen; i++) {
      final srcPos = i * ratio;
      final srcIdx = srcPos.floor();
      final frac = srcPos - srcIdx;

      if (srcIdx + 1 < samples.length) {
        out[i] = samples[srcIdx] * (1.0 - frac) + samples[srcIdx + 1] * frac;
      } else {
        out[i] = samples[srcIdx.clamp(0, samples.length - 1)];
      }
    }

    return out;
  }

  /// YIN-based pitch detection (fallback).
  List<PitchPoint> _detectWithYin(Float64List samples, int sampleRate) {
    return AudioProcessor.detectPitch(samples, sampleRate);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
    _aiEnabled = false;
  }
}
