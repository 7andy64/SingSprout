import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Alibaba Cloud DashScope (百炼) API service.
///
/// Uses Qwen model via OpenAI-compatible endpoint to enhance
/// music arrangement with AI-suggested chord progressions,
/// tempo, and style variations. Completely optional — the
/// rule engine runs fine without it.
class DashScopeService {
  static final DashScopeService _instance = DashScopeService._();
  factory DashScopeService() => _instance;
  DashScopeService._();

  static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
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

  /// AI-enhanced arrangement from melody MIDI data.
  ///
  /// Sends the detected melody notes + style to Qwen and returns
  /// structured arrangement parameters that are fed into the rule engine.
  ///
  /// Returns null if AI is unavailable (no key, network error, etc.)
  /// — caller should fall back to rule-based engine.
  Future<AiArrangementRecipe?> enhanceArrangement({
    required List<Map<String, dynamic>> melodyNotes,
    required String styleLabel,
    required double totalDuration,
    required int tonicMidi,
  }) async {
    final key = await _getKey();
    if (key == null || key.isEmpty) return null;

    final melodySummary = _formatMelody(melodyNotes, totalDuration);

    final systemPrompt = '''
你是一个儿童音乐创作助手。根据用户提供的哼唱旋律（MIDI音符序列），
为这段旋律设计伴奏编排。返回纯JSON（不要markdown包裹）：

{
  "chord_progression": [1, 5, 6, 4],
  "tempo_bpm": 85,
  "bass_style": "root_on_beats",
  "chord_style": "arpeggiated",
  "add_percussion": false,
  "mood_note": "这段旋律听起来活泼明亮…"
}

和弦级数用数字1-6表示（C大调: 1=C, 2=Dm, 3=Em, 4=F, 5=G, 6=Am）。
bass_style 可选: root_on_beats, held, alternating。
chord_style 可选: arpeggiated, pad, staccato。
只返回JSON，不要其他内容。''';

    final userPrompt = '''
风格: $styleLabel
主音: MIDI $tonicMidi
时长: ${totalDuration.toStringAsFixed(1)}秒
旋律音符: $melodySummary

请为这段儿童哼唱旋律设计合适的伴奏编排。''';

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
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.7,
              'max_tokens': 400,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[DashScope] API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final content = choices[0]['message']['content'] as String?;
      if (content == null) return null;

      return _parseRecipe(content);
    } catch (e) {
      debugPrint('[DashScope] Request failed: $e');
      return null;
    }
  }

  /// Parse the AI response into a structured recipe.
  AiArrangementRecipe? _parseRecipe(String raw) {
    try {
      // Strip possible markdown fences
      var jsonStr = raw.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final obj = jsonDecode(jsonStr) as Map<String, dynamic>;

      final progression = (obj['chord_progression'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .where((e) => e >= 1 && e <= 6)
          .toList();

      final tempo = (obj['tempo_bpm'] as num?)?.toDouble();
      final bassStyle = obj['bass_style'] as String?;
      final chordStyle = obj['chord_style'] as String?;
      final addPercussion = obj['add_percussion'] as bool?;
      final moodNote = obj['mood_note'] as String?;

      if (progression == null || progression.isEmpty || tempo == null) {
        debugPrint('[DashScope] Invalid recipe: missing required fields');
        return null;
      }

      return AiArrangementRecipe(
        chordProgression: progression,
        tempoBpm: tempo.clamp(40, 140),
        bassStyle: _parseBassStyle(bassStyle),
        chordStyle: _parseChordStyle(chordStyle),
        addPercussion: addPercussion ?? false,
        moodNote: moodNote,
      );
    } catch (e) {
      debugPrint('[DashScope] Failed to parse recipe: $e');
      return null;
    }
  }

  AiBassStyle _parseBassStyle(String? s) {
    switch (s) {
      case 'held': return AiBassStyle.held;
      case 'alternating': return AiBassStyle.alternating;
      default: return AiBassStyle.rootOnBeats;
    }
  }

  AiChordStyle _parseChordStyle(String? s) {
    switch (s) {
      case 'pad': return AiChordStyle.pad;
      case 'staccato': return AiChordStyle.staccato;
      default: return AiChordStyle.arpeggiated;
    }
  }

  /// Format melody notes as a brief text summary for the AI prompt.
  String _formatMelody(List<Map<String, dynamic>> notes, double totalDuration) {
    if (notes.isEmpty) return '无旋律音符';

    final midiNums = notes.map((n) => n['noteNumber'].toString()).join(', ');
    final uniqueNotes = notes.map((n) => n['noteNumber'] as int).toSet();
    final avgMidi = uniqueNotes.reduce((a, b) => a + b) ~/ uniqueNotes.length;

    // MIDI note name helper
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = '${noteNames[avgMidi % 12]}${avgMidi ~/ 12 - 1}';

    return '${notes.length}个音符, '
        '音高范围: $midiNums, '
        '平均音高: $noteName (MIDI $avgMidi), '
        '时长: ${totalDuration.toStringAsFixed(1)}秒';
  }

  void dispose() {
    _client.close();
  }
}

/// Structured arrangement recipe returned by AI.
class AiArrangementRecipe {
  final List<int> chordProgression;
  final double tempoBpm;
  final AiBassStyle bassStyle;
  final AiChordStyle chordStyle;
  final bool addPercussion;
  final String? moodNote;

  const AiArrangementRecipe({
    required this.chordProgression,
    required this.tempoBpm,
    required this.bassStyle,
    required this.chordStyle,
    this.addPercussion = false,
    this.moodNote,
  });
}

enum AiBassStyle { rootOnBeats, held, alternating }
enum AiChordStyle { arpeggiated, pad, staccato }
