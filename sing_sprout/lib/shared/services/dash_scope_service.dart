import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Alibaba Cloud DashScope (百炼) API service.
///
/// Three capabilities:
/// 1. Full-score generation — AI writes per-bar bass, chords, rhythm,
///    percussion, and optionally melody (speech mode). No templates.
/// 2. Speech transcription — file-based ASR via DashScope's native API.
/// 3. Legacy recipe mode — kept for compatibility.
class DashScopeService {
  static final DashScopeService _instance = DashScopeService._();
  factory DashScopeService() => _instance;
  DashScopeService._();

  static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  static const _asrUrl = 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/paraformer-realtime-v2';
  static const _asrFallbackUrl = 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/sensevoice-v1';
  static const _model = 'qwen-plus';
  static const _keyStorageKey = 'dashscope_api_key';

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  String? _cachedKey;
  bool _keyChecked = false;

  /// Whether an API key has been configured.
  Future<bool> get isConfigured async {
    if (_cachedKey != null) return true;
    if (_keyChecked) return false;
    _cachedKey = await _storage.read(key: _keyStorageKey);
    _keyChecked = true;
    return _cachedKey != null && _cachedKey!.isNotEmpty;
  }

  /// Store the API key securely.
  Future<void> setApiKey(String key) async {
    _cachedKey = key.trim();
    _keyChecked = true;
    await _storage.write(key: _keyStorageKey, value: _cachedKey);
  }

  /// Remove the stored API key.
  Future<void> clearApiKey() async {
    _cachedKey = null;
    _keyChecked = true;
    await _storage.delete(key: _keyStorageKey);
  }

  /// Get the stored key (or null).
  Future<String?> _getKey() async {
    if (_cachedKey != null) return _cachedKey;
    _cachedKey = await _storage.read(key: _keyStorageKey);
    _keyChecked = true;
    return _cachedKey;
  }

  /// Test whether a given API key is valid.
  Future<String?> testConnection({String? keyOverride}) async {
    final key = keyOverride ?? await _getKey();
    if (key == null || key.isEmpty) return '未设置 API Key';
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [{'role': 'user', 'content': 'hi'}],
              'max_tokens': 5,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['error'] as Map<String, dynamic>?;
        return (err?['message'] as String?) ?? 'API 返回错误 (${response.statusCode})';
      } catch (_) {
        return 'API 返回错误 (${response.statusCode})';
      }
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) return '连接超时，请检查网络';
      final s = e.toString();
      return '连接失败: ${s.length > 60 ? s.substring(0, 60) : s}';
    }
  }

  // ═══════════════════════════════════════════
  // Speech transcription (file-based, no mic conflict)
  // ═══════════════════════════════════════════

  /// Transcribe a WAV file using DashScope's ASR APIs.
  ///
  /// Tries Paraformer first, falls back to SenseVoice.
  /// Called after recording completes — no mic conflict.
  Future<String?> transcribeFile(String wavFilePath) async {
    final key = await _getKey();
    if (key == null || key.isEmpty) return null;

    final file = File(wavFilePath);
    if (!await file.exists()) {
      debugPrint('[DashScope] ASR: file not found');
      return null;
    }

    final rawBytes = await file.readAsBytes();
    final pcm16k = _wavToPcm16k(rawBytes);
    if (pcm16k == null) {
      debugPrint('[DashScope] ASR: failed to parse WAV');
      return null;
    }

    // Try Paraformer first, then SenseVoice fallback
    final result = await _tryAsrCall(
      _asrUrl, 'paraformer-realtime-v2', pcm16k, key,
    );
    if (result != null) return result;

    debugPrint('[DashScope] ASR: Paraformer failed, trying SenseVoice...');
    return _tryAsrCall(
      _asrFallbackUrl, 'sensevoice-v1', pcm16k, key,
    );
  }

  Future<String?> _tryAsrCall(
    String url, String model, Uint8List pcm16k, String key,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
              'X-DashScope-DataInspection': 'enable',
            },
            body: jsonEncode({
              'model': model,
              'input': {'audio': base64Encode(pcm16k)},
              'parameters': {
                'format': 'pcm',
                'sample_rate': 16000,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('[DashScope] ASR $model error ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final output = body['output'] as Map<String, dynamic>?;
      if (output == null) return null;

      final sentences = output['sentences'] as List<dynamic>?;
      if (sentences != null && sentences.isNotEmpty) {
        final text = sentences.map((s) => (s['text'] as String?) ?? '').join('');
        if (text.isNotEmpty) return text;
      }

      final text = output['text'] as String?;
      if (text != null && text.isNotEmpty) return text;

      return null;
    } catch (e) {
      debugPrint('[DashScope] ASR $model exception: $e');
      return null;
    }
  }

  /// Parse a WAV file and convert to 16kHz mono PCM.
  /// Returns raw PCM bytes or null if the WAV is invalid.
  Uint8List? _wavToPcm16k(Uint8List wavBytes) {
    try {
      if (wavBytes.length < 44) return null;

      final data = ByteData.view(wavBytes.buffer, wavBytes.offsetInBytes, wavBytes.length);

      // WAV header
      final riff = String.fromCharCodes(wavBytes.sublist(0, 4));
      if (riff != 'RIFF') return null;

      final sourceRate = data.getUint32(24, Endian.little);
      final numChannels = data.getUint16(22, Endian.little);
      final bitsPerSample = data.getUint16(34, Endian.little);

      if (bitsPerSample != 16) {
        debugPrint('[DashScope] ASR: only 16-bit WAV supported, got $bitsPerSample-bit');
        return null;
      }

      // Find data chunk
      var offset = 36;
      while (offset + 8 <= wavBytes.length) {
        final chunkId = String.fromCharCodes(wavBytes.sublist(offset, offset + 4));
        final chunkSize = data.getUint32(offset + 4, Endian.little);
        if (chunkId == 'data') {
          final dataStart = offset + 8;
          final dataEnd = (dataStart + chunkSize).clamp(0, wavBytes.length);
          final rawSamples = wavBytes.sublist(dataStart, dataEnd);

          // Convert to mono if stereo (average channels)
          Uint8List monoSamples;
          if (numChannels == 2) {
            monoSamples = _stereoToMono(rawSamples);
          } else {
            monoSamples = rawSamples;
          }

          // Resample to 16kHz
          if (sourceRate == 16000) {
            return monoSamples;
          }
          return _resamplePcm(monoSamples, sourceRate, 16000);
        }
        offset += 8 + chunkSize;
      }

      return null;
    } catch (e) {
      debugPrint('[DashScope] WAV parse error: $e');
      return null;
    }
  }

  /// Convert stereo 16-bit PCM to mono by averaging channels.
  Uint8List _stereoToMono(Uint8List stereo) {
    final result = Uint8List(stereo.length ~/ 2);
    final inData = ByteData.view(stereo.buffer, stereo.offsetInBytes, stereo.length);
    final outData = ByteData.view(result.buffer, result.offsetInBytes, result.length);
    for (var i = 0; i < stereo.length; i += 4) {
      final left = inData.getInt16(i, Endian.little);
      final right = inData.getInt16(i + 2, Endian.little);
      outData.setInt16(i ~/ 2, ((left + right) ~/ 2).clamp(-32768, 32767), Endian.little);
    }
    return result;
  }

  /// Simple linear-interpolation resampling.
  Uint8List _resamplePcm(Uint8List input, int sourceRate, int targetRate) {
    final ratio = sourceRate / targetRate;
    final inputSamples = input.length ~/ 2;
    final outputSamples = (inputSamples / ratio).ceil();
    final result = Uint8List(outputSamples * 2);
    final inData = ByteData.view(input.buffer, input.offsetInBytes, input.length);
    final outData = ByteData.view(result.buffer, result.offsetInBytes, result.length);

    for (var i = 0; i < outputSamples; i++) {
      final srcIdx = (i * ratio);
      final srcFloor = srcIdx.floor();
      final srcCeil = (srcFloor + 1).clamp(0, inputSamples - 1);
      final frac = srcIdx - srcFloor;

      final s1 = inData.getInt16(srcFloor.clamp(0, inputSamples - 1) * 2, Endian.little);
      final s2 = inData.getInt16(srcCeil * 2, Endian.little);
      final interpolated = (s1 + (s2 - s1) * frac).round().clamp(-32768, 32767);
      outData.setInt16(i * 2, interpolated, Endian.little);
    }
    return result;
  }

  // ═══════════════════════════════════════════
  // Full-score generation
  // ═══════════════════════════════════════════

  static const _fullScoreSystemPrompt = '''
你是一个儿童音乐编曲家。给定一段哼唱旋律的MIDI音符序列（可能附带语音识别文本），
为这段旋律创作完整的伴奏乐谱。你需要逐小节决定和弦、贝斯、节奏和打击乐。

返回纯JSON（不要markdown包裹）。格式如下：

{
  "tempo_bpm": 88,
  "mood": "活泼跳跃",
  "bars": [
    {
      "bar": 1,
      "chord": [60, 64, 67],
      "bass": [36, 36, 43, 36],
      "bass_rhythm": [1, 1, 1, 1],
      "chord_rhythm": [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
      "percussion": ["kick", null, "snare", null, "kick", null, "snare+hh", null],
      "dynamic": 0.7
    }
  ]
}

规则：
- chord: 该小节的和弦音MIDI编号列表（3-4个音）。根据旋律走向选择不同转位和高音。
  不同小节的voicing应该有所变化，不要始终用相同的排列方式。
- bass: 该小节贝斯线的MIDI编号列表。通常每拍一个音。
  根据旋律的情绪在根音、五音、八度音之间变化。上行旋律配下行贝斯，反之亦然。
- bass_rhythm: 每个贝斯音的时值（以拍为单位）。例如4/4拍中[1,1,1,1]表示每拍一个音。
- chord_rhythm: 和弦音的分解节奏（以拍为单位）。例如八分音符分解为8个0.5。
  使用不同的节奏型让伴奏有变化：有时琶音上行，有时下行，有时柱式。
- percussion: 每半拍的打击乐标识。可选项: "kick", "snare", "hh", "kick+hh", "snare+hh", null(休止)。
  根据情绪设计节奏型：活泼多用密集的hh，沉稳少用打击乐。至少有2-3种不同的小节节奏型循环。
- dynamic: 0.0-1.0 该小节力度。整个乐曲有强弱对比（如0.6→0.8→0.7→0.9）。
- tempo_bpm: 根据旋律和情绪选择60-120之间的速度。
- mood: 10字以内的情绪描述。

创作原则：
1. 仔细分析旋律音符的音高走向和节奏特点
2. 每个小节的伴奏都应该与对应位置的旋律音符相协调
3. 和弦进行要有起伏，避免反复使用同样的和弦
4. 贝斯线和旋律形成对位关系
5. 力度和打击乐密度随乐曲发展而变化，形成高潮和收束
6. 保持儿童音乐的纯真感，不要过于复杂
7. 小节数量 = 旋律总时长(秒) × tempo_bpm / 60 / 4 ，向上取整，至少4小节''';

  /// Generate a full accompaniment score from melody data.
  ///
  /// [melodyNotes] — detected MIDI notes from humming.
  /// [totalDuration] — recording duration in seconds.
  /// [tonicMidi] — estimated tonic MIDI number.
  /// [speechText] — optional speech-to-text result.
  /// [needsMelody] — if true, AI should compose the melody too (speech mode).
  Future<AiFullScore?> generateFullScore({
    required List<Map<String, dynamic>> melodyNotes,
    required double totalDuration,
    required int tonicMidi,
    String? speechText,
    bool needsMelody = false,
  }) async {
    final key = await _getKey();
    if (key == null || key.isEmpty) return null;

    final melodySummary = _formatMelody(melodyNotes, totalDuration);
    final barCount = ((totalDuration * 80 / 60 / 4).ceil()).clamp(4, 16);

    final userPrompt = StringBuffer();
    userPrompt.writeln('主音: MIDI $tonicMidi');
    userPrompt.writeln('时长: ${totalDuration.toStringAsFixed(1)}秒');
    userPrompt.writeln('预计小节数: $barCount');
    userPrompt.writeln('旋律音符: $melodySummary');

    final systemPrompt = StringBuffer(_fullScoreSystemPrompt);

    if (speechText != null && speechText.isNotEmpty) {
      userPrompt.writeln('用户说的话: "$speechText"');
      userPrompt.writeln('请根据说话内容和情绪来设计伴奏风格。');
    } else {
      userPrompt.writeln('请根据旋律特点设计伴奏。');
    }

    if (needsMelody) {
      userPrompt.writeln('注意：这段录音是说话而非哼唱，没有检测到有效的旋律。'
          '请同时创作一段完整的旋律（melody和melody_rhythm字段），'
          '与伴奏一起返回。旋律应该贴合说话内容的情绪。');
      systemPrompt.writeln('\n如果用户要求同时创作旋律，请添加以下字段：');
      systemPrompt.writeln('"melody": [64, 64, 65, 67, ...]  // MIDI音高序列，每音一个数');
      systemPrompt.writeln('"melody_rhythm": [1, 1, 1, 2, ...]  // 每个音的时值（拍），与melody一一对应');
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt.toString()},
                {'role': 'user', 'content': userPrompt.toString()},
              ],
              'temperature': 0.8,
              'max_tokens': needsMelody ? 4000 : 3000,
            }),
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        debugPrint('[DashScope] Full-score API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final content = choices[0]['message']['content'] as String?;
      if (content == null) return null;

      return _parseFullScore(content);
    } catch (e) {
      debugPrint('[DashScope] Full-score request failed: $e');
      return null;
    }
  }

  AiFullScore? _parseFullScore(String raw) {
    try {
      var jsonStr = raw.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
      final tempo = (obj['tempo_bpm'] as num?)?.toDouble();
      final mood = obj['mood'] as String?;
      final barsRaw = obj['bars'] as List<dynamic>?;

      final melodyRaw = (obj['melody'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList();
      final melodyRhythmRaw = (obj['melody_rhythm'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList();

      if (tempo == null || barsRaw == null || barsRaw.isEmpty) {
        debugPrint('[DashScope] Full-score missing required fields');
        return null;
      }

      final bars = <AiBarScore>[];
      for (final b in barsRaw) {
        final barMap = b as Map<String, dynamic>;
        final chord = (barMap['chord'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
        final bass = (barMap['bass'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
        final bassRhythm = (barMap['bass_rhythm'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList();
        final chordRhythm = (barMap['chord_rhythm'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList();
        final percussion = (barMap['percussion'] as List<dynamic>?)
            ?.map((e) => e as String?)
            .toList();
        final dynamicVal = (barMap['dynamic'] as num?)?.toDouble() ?? 0.7;

        if (chord == null || chord.isEmpty) {
          debugPrint('[DashScope] Bar missing chord');
          return null;
        }

        bars.add(AiBarScore(
          barIndex: (barMap['bar'] as num?)?.toInt() ?? bars.length + 1,
          chord: chord,
          bass: bass ?? [],
          bassRhythm: bassRhythm ?? [],
          chordRhythm: chordRhythm ?? [],
          percussion: percussion ?? [],
          dynamic_: dynamicVal.clamp(0.2, 1.0),
        ));
      }

      return AiFullScore(
        tempoBpm: tempo.clamp(50, 130),
        mood: mood ?? '',
        bars: bars,
        melody: melodyRaw,
        melodyRhythm: melodyRhythmRaw,
      );
    } catch (e) {
      debugPrint('[DashScope] Failed to parse full score: $e');
      return null;
    }
  }

  String _formatMelody(List<Map<String, dynamic>> notes, double totalDuration) {
    if (notes.isEmpty) return '无旋律音符';
    final midiNums = notes.map((n) => n['noteNumber'].toString()).join(', ');
    final uniqueNotes = notes.map((n) => n['noteNumber'] as int).toSet();
    final avgMidi = uniqueNotes.reduce((a, b) => a + b) ~/ uniqueNotes.length;
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = '${noteNames[avgMidi % 12]}${avgMidi ~/ 12 - 1}';
    return '${notes.length}个音符, '
        '音高: $midiNums, '
        '平均: $noteName (MIDI $avgMidi), '
        '时长: ${totalDuration.toStringAsFixed(1)}秒';
  }

  void dispose() => _client.close();
}

// ═══════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════

/// Full per-bar accompaniment score written by AI.
class AiFullScore {
  final double tempoBpm;
  final String mood;
  final List<AiBarScore> bars;

  /// AI-composed melody (only when needsMelody=true).
  final List<int>? melody;
  final List<double>? melodyRhythm;

  const AiFullScore({
    required this.tempoBpm,
    required this.mood,
    required this.bars,
    this.melody,
    this.melodyRhythm,
  });
}

/// One bar of AI-written accompaniment.
class AiBarScore {
  final int barIndex;
  final List<int> chord;
  final List<int> bass;
  final List<double> bassRhythm;
  final List<double> chordRhythm;
  final List<String?> percussion;
  final double dynamic_;

  const AiBarScore({
    required this.barIndex,
    required this.chord,
    required this.bass,
    required this.bassRhythm,
    required this.chordRhythm,
    required this.percussion,
    required this.dynamic_,
  });
}
