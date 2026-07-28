import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'audio_processor.dart';

/// On-device pitch detection using TFLite (CREPE-tiny) with YIN fallback.
///
/// CREPE-tiny is ~2MB, runs ~50ms per frame on low-end Android.
/// YIN is 0MB, runs ~20ms per frame but less accurate in noisy environments.
class PitchDetectionService {
  static final PitchDetectionService _instance = PitchDetectionService._();
  factory PitchDetectionService() => _instance;
  PitchDetectionService._();

  Interpreter? _interpreter;
  bool _modelLoaded = false;

  /// Initialize TFLite model from assets. Call once at app startup.
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/crepe_tiny.tflite');
      _modelLoaded = true;
      debugPrint('[PitchDetection] TFLite model loaded');
    } catch (e) {
      debugPrint('[PitchDetection] TFLite model not available, using YIN fallback: $e');
      _modelLoaded = false;
    }
  }

  bool get isAvailable => _modelLoaded;

  /// Detect pitch contour from audio samples.
  ///
  /// Uses TFLite if available, otherwise falls back to YIN.
  /// [samples] — normalized [-1.0, 1.0] audio samples.
  /// [sampleRate] — e.g., 44100.
  /// Returns list of (time, frequencyHz) pairs. frequencyHz = 0 means unvoiced.
  Future<List<PitchPoint>> detectPitch(
    Float64List samples,
    int sampleRate, {
    bool preferTflite = true,
  }) async {
    if (preferTflite && _modelLoaded) {
      try {
        return await _detectWithTflite(samples, sampleRate);
      } catch (e) {
        debugPrint('[PitchDetection] TFLite failed, falling back to YIN: $e');
      }
    }
    return _detectWithYin(samples, sampleRate);
  }

  /// TFLite-based pitch detection (CREPE-tiny).
  Future<List<PitchPoint>> _detectWithTflite(
    Float64List samples,
    int sampleRate,
  ) async {
    final frameSize = 1024;
    final hopSize = 512;
    final numFrames = (samples.length - frameSize) ~/ hopSize + 1;
    final results = <PitchPoint>[];

    final input = List.generate(numFrames, (_) => Float32List(frameSize));

    for (var i = 0; i < numFrames; i++) {
      final offset = i * hopSize;
      for (var j = 0; j < frameSize; j++) {
        input[i][j] = samples[offset + j].toDouble();
      }
    }

    final inputTensor = [input];
    final outputTensor = [List.generate(numFrames, (_) => Float32List(360))];

    _interpreter!.run(inputTensor, outputTensor);

    for (var i = 0; i < numFrames; i++) {
      final time = (i * hopSize) / sampleRate;
      final probs = outputTensor[0][i];

      var maxIdx = 0;
      var maxProb = probs[0];
      for (var j = 1; j < probs.length; j++) {
        if (probs[j] > maxProb) {
          maxProb = probs[j];
          maxIdx = j;
        }
      }

      // CREPE bins: 20-2000Hz, 20 cents per bin. freq = 20 * 2^(bin/60)
      final freq = maxProb > 0.5 ? 20.0 * _pow2(maxIdx / 60.0) : 0.0;

      results.add(PitchPoint(time, freq));
    }

    return results;
  }

  /// YIN-based pitch detection (fallback).
  List<PitchPoint> _detectWithYin(Float64List samples, int sampleRate) {
    return AudioProcessor.detectPitch(samples, sampleRate);
  }

  double _pow2(double x) {
    return exp(x * 0.6931471805599453); // ln(2)
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}