import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../core/constants/enums.dart';
import 'audio_processor.dart';
import 'dash_scope_service.dart';
import 'device_capability_service.dart';

/// On-device + cloud sound classification for Field Sound Lab.
///
/// Primary: YAMNet TFLite (~1.5MB, 521 AudioSet classes) on-device inference.
/// Cloud fallback: SenseVoice API via DashScopeService.
/// BPM estimation: on-device energy-based onset detection.
class SoundClassificationService {
  static final SoundClassificationService _instance = SoundClassificationService._();
  factory SoundClassificationService() => _instance;
  SoundClassificationService._();

  final _dashScope = DashScopeService();

  Interpreter? _interpreter;
  bool _yamnetLoaded = false;
  final List<String> _classNames = [];

  // YAMNet constants
  static const int _targetSampleRate = 16000;
  static const int _windowSamples = 15600; // 0.975s
  static const int _hopSamples = 7520;
  static const int _numClasses = 521;

  /// Try to load YAMNet TFLite model. Call once at app startup.
  /// Skips on low-end devices (<2GB RAM).
  Future<void> initialize() async {
    final caps = DeviceCapabilityService();
    if (!caps.shouldUseAIPitchDetection) {
      debugPrint('[SoundClass] Low-end device, skipping YAMNet');
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');

      // Load class names
      final csvData = await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      final lines = csvData.split('\n');
      for (var i = 1; i < lines.length; i++) {
        // CSV format: index,mid,display_name
        final parts = lines[i].split(',');
        if (parts.length >= 3) {
          var name = parts.sublist(2).join(',').trim();
          if (name.startsWith('"') && name.endsWith('"')) {
            name = name.substring(1, name.length - 1);
          }
          _classNames.add(name);
        }
      }

      // Verify model shape matches expectations
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      if (inputShape.length < 2 || outputShape.length < 3 || outputShape[2] != _numClasses) {
        debugPrint('[SoundClass] YAMNet unexpected shapes: in=$inputShape out=$outputShape');
        _interpreter?.close();
        _interpreter = null;
        return;
      }

      _yamnetLoaded = true;
      debugPrint('[SoundClass] YAMNet loaded (${_classNames.length} classes)');
    } catch (e) {
      debugPrint('[SoundClass] YAMNet not available, using SenseVoice cloud: $e');
      _interpreter?.close();
      _interpreter = null;
      _yamnetLoaded = false;
    }
  }

  bool get isYamnetAvailable => _yamnetLoaded;

  /// Analyze a recorded WAV file.
  ///
  /// Tries YAMNet on-device first (fast, offline), falls back to SenseVoice
  /// cloud (requires API key + network). BPM estimation always runs locally.
  Future<SoundAnalysisResult> analyze(String wavFilePath) async {
    // Run classification and BPM in parallel
    final results = await Future.wait([
      _classify(wavFilePath),
      _estimateBpm(wavFilePath),
    ]);

    final events = results[0] as _EventMeta?;
    final bpm = results[1] as double;

    final soundType = events != null ? _mapToSoundType(events) : SoundType.unknown;
    final hint = _generateHint(soundType, events, bpm);

    return SoundAnalysisResult(
      soundType: soundType,
      bpm: bpm,
      recommendedUse: hint,
      rawLabels: events?.labels ?? [],
      confidence: events?.confidence ?? 0.0,
    );
  }

  /// Classification: YAMNet first, SenseVoice cloud fallback.
  Future<_EventMeta?> _classify(String wavFilePath) async {
    if (_yamnetLoaded) {
      try {
        return await _classifyWithYamnet(wavFilePath);
      } catch (e) {
        debugPrint('[SoundClass] YAMNet inference failed: $e');
      }
    }
    return await _classifyWithSenseVoice(wavFilePath);
  }

  /// YAMNet on-device classification.
  Future<_EventMeta?> _classifyWithYamnet(String wavFilePath) async {
    final samples = await AudioProcessor.readWav(wavFilePath);
    if (samples.length < _windowSamples) return null;

    // Resample 44100→16000
    final audio16k = _resample(samples, 44100, _targetSampleRate);

    // Aggregate scores across all windows
    final aggregated = Float64List(_numClasses);
    var windowCount = 0;

    for (var offset = 0; offset + _windowSamples <= audio16k.length; offset += _hopSamples) {
      final input = Float32List(_windowSamples);
      for (var i = 0; i < _windowSamples; i++) {
        input[i] = audio16k[offset + i].toDouble();
      }

      final output = [List.generate(1, (_) => Float32List(_numClasses))];

      _interpreter!.run([input], {0: output});

      for (var c = 0; c < _numClasses; c++) {
        aggregated[c] += output[0][0][c];
      }
      windowCount++;
    }

    if (windowCount == 0) return null;

    // Normalize and find top classes
    final indices = List.generate(_numClasses, (i) => i);
    indices.sort((a, b) => aggregated[b].compareTo(aggregated[a]));

    const topK = 5;
    final labels = <String>[];
    var topConfidence = 0.0;
    for (var i = 0; i < topK && i < _numClasses; i++) {
      final idx = indices[i];
      final score = aggregated[idx] / windowCount;
      final sigmoid = 1.0 / (1.0 + exp(-score.clamp(-10.0, 10.0)));
      if (i == 0) topConfidence = sigmoid;
      if (sigmoid > 0.1 && idx < _classNames.length) {
        labels.add(_classNames[idx]);
      }
    }

    // Determine categories based on AudioSet ontology
    var hasSpeech = false;
    var hasMusic = false;
    var hasEnvironmental = false;
    for (final label in labels) {
      final lower = label.toLowerCase();
      if (!hasSpeech && _isSpeechClass(index: indices[0], label: lower)) { hasSpeech = true; }
      if (!hasMusic && (lower.contains('music') || lower.contains('musical') ||
          lower.contains('song') || lower.contains('sing'))) { hasMusic = true; }
      if (!hasEnvironmental && (_isNatureClass(lower) || _isAnimalClass(lower))) {
        hasEnvironmental = true;
      }
    }

    return _EventMeta(
      labels: labels,
      confidence: topConfidence,
      hasSpeech: hasSpeech,
      hasMusic: hasMusic,
      hasEnvironmental: hasEnvironmental,
    );
  }

  bool _isSpeechClass({required int index, required String label}) {
    // AudioSet speech-related classes
    return label.contains('speech') || label.contains('speak') ||
        label.contains('voice') || label.contains('narration') ||
        label.contains('conversation') || label.contains('talk') ||
        label.contains('laughter') || label.contains('cry') ||
        label.contains('shout') || label.contains('whisper') ||
        label.contains('singing') || label.contains('humming') ||
        label.contains('child') && label.contains('speech');
  }

  bool _isAnimalClass(String label) {
    return label.contains('animal') || label.contains('bird') ||
        label.contains('dog') || label.contains('cat') ||
        label.contains('insect') || label.contains('frog') ||
        label.contains('livestock') || label.contains('wild') ||
        label.contains('canidae') || label.contains('felidae') ||
        label.contains('roar') || label.contains('growl') ||
        label.contains('chirp') || label.contains('howl') ||
        label.contains('bark') || label.contains('meow');
  }

  bool _isNatureClass(String label) {
    return label.contains('wind') || label.contains('rain') ||
        label.contains('water') || label.contains('ocean') ||
        label.contains('wave') || label.contains('stream') ||
        label.contains('thunder') || label.contains('thunderstorm') ||
        label.contains('weather') || label.contains('outdoor') ||
        label.contains('nature') || label.contains('fire') ||
        label.contains('river') || label.contains('waterfall');
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

  /// SenseVoice cloud classification.
  Future<_EventMeta?> _classifyWithSenseVoice(String wavFilePath) async {
    try {
      final result = await _dashScope.detectAudioEvents(wavFilePath);
      if (result == null || result.events.isEmpty) return null;

      final labels = result.events.map((e) => e.label).toList();
      final confidence = result.events.fold<double>(
        0.0, (sum, e) => sum + e.confidence,
      ) / result.events.length;

      return _EventMeta(
        labels: labels,
        confidence: confidence,
        hasSpeech: result.hasSpeech,
        hasMusic: result.hasMusic,
        hasEnvironmental: result.hasEnvironmental,
      );
    } catch (e) {
      debugPrint('[SoundClass] SenseVoice failed: $e');
      return null;
    }
  }

  /// Map classification labels to SoundType.
  SoundType _mapToSoundType(_EventMeta meta) {
    final allLabels = meta.labels.map((l) => l.toLowerCase()).toList().join(' ');

    if (meta.hasSpeech || allLabels.contains('speech') || allLabels.contains('human') ||
        allLabels.contains('singing') || allLabels.contains('laughter') ||
        allLabels.contains('voice')) {
      return SoundType.humanVoice;
    }
    if (_isAnimalClass(allLabels)) {
      return SoundType.animal;
    }
    if (meta.hasEnvironmental || _isNatureClass(allLabels)) {
      return SoundType.nature;
    }
    if (allLabels.contains('mechanical') || allLabels.contains('engine') ||
        allLabels.contains('vehicle') || allLabels.contains('machine') ||
        allLabels.contains('urban') || allLabels.contains('traffic') ||
        allLabels.contains('tool')) {
      return SoundType.mechanical;
    }
    if (meta.hasMusic) return SoundType.humanVoice;

    return SoundType.unknown;
  }

  /// On-device energy-based onset detection for BPM estimation.
  Future<double> _estimateBpm(String wavFilePath) async {
    try {
      final samples = await AudioProcessor.readWav(wavFilePath);
      if (samples.length < 2048) return 0;

      const sampleRate = 44100;
      const hopSize = 512;

      final odf = <double>[];
      var prevEnergy = 0.0;
      for (var i = 0; i + hopSize <= samples.length; i += hopSize) {
        var energy = 0.0;
        for (var j = i; j < i + hopSize; j++) {
          energy += samples[j] * samples[j];
        }
        energy /= hopSize;
        final diff = (energy - prevEnergy).clamp(0, double.infinity).toDouble();
        odf.add(diff);
        prevEnergy = energy;
      }

      if (odf.isEmpty) return 0;
      final mean = odf.reduce((a, b) => a + b) / odf.length;
      final median = _medianOf(odf);
      final threshold = median + (mean - median) * 0.5;

      final onsetFrames = <int>[];
      for (var i = 1; i < odf.length - 1; i++) {
        if (odf[i] > threshold && odf[i] > odf[i - 1] && odf[i] >= odf[i + 1]) {
          onsetFrames.add(i);
        }
      }

      if (onsetFrames.length < 3) return 0;

      final iois = <double>[];
      for (var i = 1; i < onsetFrames.length; i++) {
        final ioi = (onsetFrames[i] - onsetFrames[i - 1]) * hopSize / sampleRate;
        if (ioi > 0.2 && ioi < 2.0) {
          iois.add(ioi);
        }
      }

      if (iois.isEmpty) return 0;

      final medianIoi = _medianOf(iois);
      if (medianIoi <= 0) return 0;
      var bpm = 60.0 / medianIoi;

      while (bpm < 40) { bpm *= 2; }
      while (bpm > 200) { bpm /= 2; }

      return bpm.clamp(40, 200).roundToDouble();
    } catch (e) {
      debugPrint('[SoundClass] BPM estimation failed: $e');
      return 0;
    }
  }

  double _medianOf(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length % 2 == 0
        ? (sorted[mid - 1] + sorted[mid]) / 2
        : sorted[mid];
  }

  String _generateHint(SoundType type, _EventMeta? events, double bpm) {
    final bpmStr = bpm > 0 ? ' ${bpm.toStringAsFixed(0)} BPM' : '';

    if (events != null && events.labels.isNotEmpty) {
      final labels = events.labels.take(3).join('、');
      return '$labels — ${_baseHint(type)}$bpmStr';
    }

    return _baseHint(type) + bpmStr;
  }

  String _baseHint(SoundType type) {
    switch (type) {
      case SoundType.nature:
        return '这个声音适合做背景环境音，搭配钢琴旋律效果很好';
      case SoundType.animal:
        return '这个声音适合做节奏点缀，试试放在副歌段落';
      case SoundType.humanVoice:
        return '这段人声适合做旋律主线，可以试试调音或变调';
      case SoundType.mechanical:
        return '这个声音适合做打击乐底子，试试循环播放';
      case SoundType.unknown:
        return '这个声音很有特色，可以试试不同的音乐风格';
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _yamnetLoaded = false;
  }
}

class SoundAnalysisResult {
  final SoundType soundType;
  final double bpm;
  final String recommendedUse;
  final List<String> rawLabels;
  final double confidence;

  const SoundAnalysisResult({
    required this.soundType,
    required this.bpm,
    required this.recommendedUse,
    required this.rawLabels,
    required this.confidence,
  });
}

class _EventMeta {
  final List<String> labels;
  final double confidence;
  final bool hasSpeech;
  final bool hasMusic;
  final bool hasEnvironmental;

  const _EventMeta({
    required this.labels,
    required this.confidence,
    this.hasSpeech = false,
    this.hasMusic = false,
    this.hasEnvironmental = false,
  });
}
