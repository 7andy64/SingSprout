import 'dart:convert';
import 'dart:io';
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
  static const _asrBase = 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr';

  /// ASR model chain: tried in order. paraformer-mtl-v1 supports
  /// Southwestern Mandarin, Cantonese, and Hakka dialects natively.
  static const _asrModelChain = [
    'paraformer-mtl-v1',
    'paraformer-realtime-v2',
    'sensevoice-v1',
  ];

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
  /// Tries models in chain order: paraformer-mtl-v1 (multi-dialect),
  /// paraformer-realtime-v2, then sensevoice-v1.
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

    for (final model in _asrModelChain) {
      final url = '$_asrBase/$model';
      final result = await _tryAsrCall(url, model, pcm16k, key);
      if (result != null) return result;
      debugPrint('[DashScope] ASR: $model failed, trying next...');
    }
    return null;
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
  // Audio event detection (SenseVoice)
  // ═══════════════════════════════════════════

  /// Result of audio event / sound classification.
  AudioEventResult? _lastEventCache;

  /// Detect sound events in a short audio clip using SenseVoice.
  ///
  /// Returns structured event data — sound type, confidence, and
  /// whether speech/music/environmental sounds are present.
  /// Useful for "Field Sound Lab" auto-classification.
  Future<AudioEventResult?> detectAudioEvents(String wavFilePath) async {
    final key = await _getKey();
    if (key == null || key.isEmpty) return null;

    final file = File(wavFilePath);
    if (!await file.exists()) return null;

    final rawBytes = await file.readAsBytes();
    final pcm16k = _wavToPcm16k(rawBytes);
    if (pcm16k == null) return null;

    try {
      final response = await _client
          .post(
            Uri.parse('$_asrBase/sensevoice-v1'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'sensevoice-v1',
              'input': {'audio': base64Encode(pcm16k)},
              'parameters': {
                'format': 'pcm',
                'sample_rate': 16000,
                'audio_event_detection': true,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final output = body['output'] as Map<String, dynamic>?;
      if (output == null) return null;

      final events = (output['events'] as List<dynamic>?)
          ?.map((e) => AudioEvent(
                label: (e['label'] as String?) ?? '',
                confidence: (e['confidence'] as num?)?.toDouble() ?? 0.0,
              ),)
          .toList();

      if (events != null && events.isNotEmpty) {
        final result = AudioEventResult(
          events: events,
          hasSpeech: events.any((e) => e.label.contains('Speech')),
          hasMusic: events.any((e) => e.label.contains('Music')),
          hasEnvironmental: events.any((e) =>
              e.label.contains('Nature') || e.label.contains('Animal'),),
        );
        _lastEventCache = result;
        return result;
      }

      return null;
    } catch (e) {
      debugPrint('[DashScope] Audio event detection failed: $e');
      return null;
    }
  }

  /// Get the last cached event result (avoids re-calling API).
  AudioEventResult? get lastEventResult => _lastEventCache;

  // ═══════════════════════════════════════════
  // Full-score generation
  // ═══════════════════════════════════════════

  static const _fullScoreSystemPrompt = '''
你是一个儿童音乐编曲家，专门为中国乡村儿童创作温暖、纯真的音乐。
给定一段哼唱旋律的MIDI音符序列（可能附带语音识别文本和环境声音描述），
为这段旋律创作完整的伴奏乐谱。你需要逐小节决定和弦、贝斯、节奏和打击乐。

返回纯JSON（不要markdown包裹）。格式如下：

{
  "tempo_bpm": 88,
  "mood": "活泼跳跃",
  "key_tonality": "C大调",
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
- chord: 该小节的和弦音MIDI编号列表（3-4个音）。优先使用主和弦(I)、下属和弦(IV)、
  属和弦(V)、关系小调和弦(vi)。根据旋律走向选择不同转位和高音。
  五声音阶旋律偏好I-IV-V-I或I-vi-IV-V进行。前奏用主和弦定位调性，终止式用V-I。
- bass: 该小节贝斯线的MIDI编号列表。通常每拍一个音。
  根音(下方八度)为主，在旋律长音处用五音或经过音增加动感。
  上行旋律配下行贝斯形成反向进行。BASS音高范围：MIDI 28-55。
- bass_rhythm: 每个贝斯音的时值（以拍为单位）。例如4/4拍中[1,1,1,1]表示每拍一个音。
  可在第3-4拍加入切分音[1, 0.5, 0.5, 1, 1]增加律动感。
- chord_rhythm: 和弦音的分解节奏（以拍为单位）。使用至少3种节奏型轮换：
  柱式和弦[4]、八分音符上行[0.5×8]、八分音符下行[0.5×8]、附点节奏[0.75,0.25,...]。
  同一节奏型不超过连续2小节。
- percussion: 每半拍的打击乐标识。可选项: "kick", "snare", "hh", "kick+hh", "snare+hh", "clap", null(休止)。
  基本框架：kick在第1、3拍，snare在第2、4拍，hh填充八分音符。clap在第2、4拍加强。
  每4小节为一个段落，第4小节加fill变化（如"kick", "snare", "kick+hh", "snare+hh", "kick", "kick", "snare+hh", "hh"）。
  欢快风格hihat密集，抒情风格只用kick+snare骨架。
- dynamic: 0.0-1.0 该小节力度。整曲有情绪弧线：
  前奏(0.5-0.6) → 主题进入(0.7-0.75) → 高潮(0.8-0.9) → 收束(0.6-0.5)。
  高潮通常在总小节数的60%-80%位置。
- tempo_bpm: 根据旋律密度选择。密集→80-90，稀疏→90-110，中等→70-85。
  儿童音乐一般偏快但不急促，以孩子能跟随拍手为宜。
- mood: 8字以内的情绪描述（如"晨露初醒"、"溪水欢唱"、"雨后蛙鸣"）。
- key_tonality: 调性描述（如"C大调"、"a小调"）。根据旋律尾音和主音MIDI判断。

创作原则：
1. 分析旋律音符的音高走向，判断是大调还是五声音阶，据此选择调性和和弦
2. 和弦选配以五声音阶为主（大调：do-re-mi-sol-la；小调：la-do-re-mi-sol）
3. 每4小节为一个乐句，偶数小节用V或IV制造"问句"，奇数终止用I制造"答句"
4. 贝斯与旋律保持三度以上音程距离，形成清晰的对位层次
5. 前2小节作为前奏（只有伴奏无旋律呼应），最后1小节渐慢收束
6. 保持儿童音乐的纯真感：避免半音阶和过于复杂的和声
7. 如果提供了环境声音信息（鸟鸣、水声等），在编曲中融入自然感
8. 小节数量 = ceil(旋律总时长(秒) × tempo_bpm / 60 / 4)，至少4小节，最多16小节''';

  /// Generate a full accompaniment score from melody data.
  ///
  /// [melodyNotes] — detected MIDI notes from humming.
  /// [totalDuration] — recording duration in seconds.
  /// [tonicMidi] — estimated tonic MIDI number.
  /// [speechText] — optional speech-to-text result.
  /// [needsMelody] — if true, AI should compose the melody too (speech mode).
  /// [audioEvents] — optional description of detected sounds in the recording.
  Future<AiFullScore?> generateFullScore({
    required List<Map<String, dynamic>> melodyNotes,
    required double totalDuration,
    required int tonicMidi,
    String? speechText,
    bool needsMelody = false,
    String? audioEvents,
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

    if (audioEvents != null && audioEvents.isNotEmpty) {
      userPrompt.writeln('环境声音: $audioEvents');
      userPrompt.writeln('请将这些自然声音的感觉融入编曲风格中。');
    }

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
        ),);
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

  /// Format melody notes as a brief text summary for the AI prompt.
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

/// AI bass accompaniment style.
enum AiBassStyle {
  held,
  alternating,
  rootOnBeats,
}

/// AI chord accompaniment style.
enum AiChordStyle {
  pad,
  staccato,
  arpeggiated,
}

/// AI-generated arrangement recipe — creative decisions made by AI.
class AiArrangementRecipe {
  final AiChordStyle chordStyle;
  final AiBassStyle bassStyle;
  final List<int> chordProgression;
  final double tempoBpm;
  final bool addPercussion;

  const AiArrangementRecipe({
    required this.chordStyle,
    required this.bassStyle,
    required this.chordProgression,
    required this.tempoBpm,
    this.addPercussion = false,
  });
}

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

/// A single sound event detected by SenseVoice.
class AudioEvent {
  final String label;
  final double confidence;

  const AudioEvent({required this.label, required this.confidence});

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Aggregated audio event detection result.
class AudioEventResult {
  final List<AudioEvent> events;
  final bool hasSpeech;
  final bool hasMusic;
  final bool hasEnvironmental;

  const AudioEventResult({
    required this.events,
    this.hasSpeech = false,
    this.hasMusic = false,
    this.hasEnvironmental = false,
  });

  /// Human-readable summary for use in prompts.
  String get summary {
    if (events.isEmpty) return '';
    final labels = events.take(3).map((e) => e.toString()).join(', ');
    final categories = <String>[];
    if (hasSpeech) categories.add('人声');
    if (hasMusic) categories.add('音乐');
    if (hasEnvironmental) categories.add('自然环境声');
    final catStr = categories.isNotEmpty ? ' (${categories.join('/')})' : '';
    return '$labels$catStr';
  }

  @override
  String toString() => summary;
}
