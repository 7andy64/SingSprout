import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_music_models.dart';
import 'dash_scope_service.dart';
import 'audio_processor.dart';

/// Generates AI music for the rhythm game.
///
/// Calls DashScope qwen-plus to compose melody + percussion as JSON,
/// then synthesizes the result to WAV locally.
class AiMusicService {
  static final AiMusicService _instance = AiMusicService._();
  factory AiMusicService() => _instance;
  AiMusicService._();

  static const _sampleRate = 22050;
  static const _durationSeconds = 30;

  /// Generate a complete music track for the rhythm game.
  ///
  /// Retries up to [_maxRetries] times on failure. Falls back to procedural
  /// note generation if all AI attempts fail. Returns a valid result in most
  /// cases — null only when WAV synthesis itself fails with no recovery.
  Future<AiMusicResult?> generateGameMusic(AiMusicStyle style) async {
    final dashScope = DashScopeService();
    final isConfigured = await dashScope.isConfigured;
    if (!isConfigured) {
      debugPrint('[AiMusicService] DashScope not configured, using procedural fallback');
      return proceduralMusic(style);
    }

    // Try AI generation (single attempt for speed)
    for (var attempt = 0; attempt < _maxRetries; attempt++) {

      final rawJson = await dashScope.chatCompletion(
        systemPrompt: _systemPrompt(style),
        userMessage:
            '请为节奏游戏创作一段$_durationSeconds秒的${style.label}风格音乐。直接返回JSON，不要解释。',
        temperature: 0.9,
        maxTokens: 4096,
      );

      if (rawJson == null) {
        debugPrint('[AiMusicService] Attempt $attempt: AI returned null');
        continue;
      }

      final parsed = _parseMusicJson(rawJson, style);
      if (parsed == null) {
        debugPrint('[AiMusicService] Attempt $attempt: failed to parse');
        continue;
      }

      final melodyNotes = parsed['melody'] as List<AiGameNote>;
      final percussionNotes = parsed['percussion'] as List<AiGameNote>;
      final tempo = parsed['tempo'] as double;
      final mood = parsed['mood'] as String;

      if (melodyNotes.length < 20 || percussionNotes.length < 10) {
        debugPrint('[AiMusicService] Attempt $attempt: too few notes (m=${melodyNotes.length} p=${percussionNotes.length})');
        continue;
      }

      final wavPath = await _synthesizeWav(melodyNotes, percussionNotes, tempo);
      if (wavPath == null) {
        debugPrint('[AiMusicService] Attempt $attempt: WAV synthesis failed');
        continue;
      }

      final allNotes = [...melodyNotes, ...percussionNotes]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      debugPrint('[AiMusicService] AI generation succeeded on attempt ${attempt + 1}');
      return AiMusicResult(
        wavPath: wavPath,
        notes: allNotes,
        tempo: tempo,
        mood: mood,
      );
    }

    // All AI attempts exhausted — use procedural fallback
    debugPrint('[AiMusicService] All AI attempts failed, using procedural music');
    return proceduralMusic(style);
  }

  static const _maxRetries = 1;

  /// Procedural music generation — always fast, no network.
  ///
  /// Generates pentatonic melody + style-appropriate percussion patterns
  /// without any network calls. Used as fast-path first play, and fallback
  /// when AI is unavailable.
  Future<AiMusicResult> proceduralMusic(AiMusicStyle style) async {
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final cfg = _styleConfig(style);
    final tempo = cfg.tempo;
    final beatsPerSecond = tempo / 60;
    final totalBeats = _durationSeconds * beatsPerSecond;

    // Generate melody notes (pentatonic scale in G3-C6 range)
    const pentatonic = [55, 57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84];
    final melodyNotes = <AiGameNote>[];
    var time = 0.0;
    while (time < _durationSeconds - 0.3) {
      final pitch = pentatonic[rng.nextInt(pentatonic.length)];
      final dur = (0.15 + rng.nextDouble() * cfg.maxNoteDuration)
          .clamp(0.12, 1.2);
      melodyNotes.add(
        AiGameNote(
          pitch: pitch,
          startTime: time,
          duration: dur,
          isPercussion: false,
        ),
      );
      time += cfg.noteInterval + rng.nextDouble() * cfg.noteIntervalVariance;
    }

    // Generate percussion
    final percussionNotes = <AiGameNote>[];
    for (var beat = 0.0; beat < totalBeats; beat += cfg.percussionGrid) {
      final t = beat / beatsPerSecond;
      if (t >= _durationSeconds) break;

      // Kick pattern
      if (beat.floor() % cfg.kickEvery == 0) {
        percussionNotes.add(
          AiGameNote(
            pitch: 36,
            startTime: t,
            duration: 0.1,
            isPercussion: true,
            percussionType: 'kick',
          ),
        );
      }
      // Snare pattern
      if ((beat + cfg.snareOffset).floor() % cfg.snareEvery == 0) {
        percussionNotes.add(
          AiGameNote(
            pitch: 38,
            startTime: t,
            duration: 0.1,
            isPercussion: true,
            percussionType: 'snare',
          ),
        );
      }
      // Hi-hat fill
      if (rng.nextDouble() < cfg.hhProbability) {
        percussionNotes.add(
          AiGameNote(
            pitch: 42,
            startTime: t,
            duration: 0.1,
            isPercussion: true,
            percussionType: 'hh',
          ),
        );
      }
    }

    final wavPath = await _synthesizeWav(melodyNotes, percussionNotes, tempo);
    if (wavPath == null) {
      throw Exception('[AiMusicService] Procedural WAV synthesis failed');
    }

    final allNotes = [...melodyNotes, ...percussionNotes]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return AiMusicResult(
      wavPath: wavPath,
      notes: allNotes,
      tempo: tempo,
      mood: style.label,
    );
  }

  /// Per-style configuration for procedural generation.
  _StyleCfg _styleConfig(AiMusicStyle style) {
    return switch (style) {
      AiMusicStyle.happy => const _StyleCfg(
          tempo: 120, noteInterval: 0.18, noteIntervalVariance: 0.15,
          maxNoteDuration: 0.8, percussionGrid: 0.5, kickEvery: 1,
          snareOffset: 0.5, snareEvery: 2, hhProbability: 0.6,
        ),
      AiMusicStyle.calm => const _StyleCfg(
          tempo: 75, noteInterval: 0.55, noteIntervalVariance: 0.4,
          maxNoteDuration: 1.2, percussionGrid: 1.0, kickEvery: 2,
          snareOffset: 0, snareEvery: 4, hhProbability: 0.15,
        ),
      AiMusicStyle.energetic => const _StyleCfg(
          tempo: 135, noteInterval: 0.12, noteIntervalVariance: 0.1,
          maxNoteDuration: 0.5, percussionGrid: 0.25, kickEvery: 1,
          snareOffset: 0.5, snareEvery: 2, hhProbability: 0.85,
        ),
      AiMusicStyle.electronic => const _StyleCfg(
          tempo: 125, noteInterval: 0.15, noteIntervalVariance: 0.12,
          maxNoteDuration: 0.6, percussionGrid: 0.5, kickEvery: 1,
          snareOffset: 0.25, snareEvery: 2, hhProbability: 0.7,
        ),
    };
  }

  /// Build the system prompt for the AI based on style.
  String _systemPrompt(AiMusicStyle style) {
    final styleGuide = switch (style) {
      AiMusicStyle.happy => '''
风格：欢快活泼，明亮大调，跳跃旋律，适合儿童拍手跟唱。
BPM: 100-130，节奏密集。
旋律：多用五声音阶上行跳进，装饰音点缀。
打击乐：kick每拍，snare在第2、4拍，hihat八分音符填充。''',
      AiMusicStyle.calm => '''
风格：温柔宁静，舒缓摇篮曲风，长线条旋律。
BPM: 60-85，节奏稀疏。
旋律：级进为主，长音收尾，避免大跳。
打击乐：仅kick在强拍轻点，用snare滚奏(每半拍连续轻击)过渡。''',
      AiMusicStyle.energetic => '''
风格：强烈动感，电子舞曲元素，附点节奏驱动。
BPM: 120-150，节奏密集有力。
旋律：切分节奏，短促跳跃，重复动机。
打击乐：kick四拍重击，snare反拍加强，hihat持续十六分音符。''',
      AiMusicStyle.electronic => '''
风格：现代电子合成，琶音上行，方波/锯齿波感。
BPM: 100-140，节奏规整。
旋律：琶音式上下行，模进重复，音色明亮。
打击乐：电子鼓机感，kick低沉，snare/clap交替，hihat开闭变化。''',
    };

    return '''
你是一个儿童音乐游戏作曲家。为节奏游戏创作一段$_durationSeconds秒的音乐。

$styleGuide

返回纯JSON（不要markdown包裹），格式：
{
  "tempo": <BPM数值>,
  "mood": "<8字以内中文情绪描述>",
  "melody": [
    {"pitch": <MIDI 55-84>, "startTime": <秒>, "duration": <秒>},
    ...
  ],
  "percussion": [
    {"type": "<kick|snare|hh>", "startTime": <秒>},
    ...
  ]
}

严格规则：
- 总时长恰好$_durationSeconds秒，最后一个音符在${_durationSeconds - 0.5}秒前结束
- 旋律音高仅在MIDI 55-84范围（G3-C6），儿童友好音域
- 使用五声音阶（C, D, E, G, A 或其移位），避免半音和不和谐音程
- 旋律密度：每秒1-4个音符（根据风格调整）
- 打击乐：按BPM节奏严格排列，每拍都有kick或snare之一
- 旋律音符的duration至少0.15秒，最多1.5秒
- 确保输出20个以上旋律音符和15个以上打击乐音符
''';
  }

  /// Parse AI response JSON into melody + percussion notes.
  Map<String, dynamic>? _parseMusicJson(String raw, AiMusicStyle style) {
    try {
      var jsonStr = raw.trim();
      // Strip markdown code fences
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }
      // If the string doesn't look like JSON, try to extract the JSON portion
      if (!jsonStr.startsWith('{')) {
        final firstBrace = jsonStr.indexOf('{');
        final lastBrace = jsonStr.lastIndexOf('}');
        if (firstBrace >= 0 && lastBrace > firstBrace) {
          jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
        }
      }
      final obj = jsonDecode(jsonStr) as Map<String, dynamic>;

      final tempo = (obj['tempo'] as num?)?.toDouble();
      final mood = (obj['mood'] as String?) ?? style.label;
      final melodyRaw = obj['melody'] as List<dynamic>?;
      final percussionRaw = obj['percussion'] as List<dynamic>?;

      if (tempo == null || melodyRaw == null || melodyRaw.isEmpty) {
        debugPrint('[AiMusicService] Missing required fields in AI response');
        return null;
      }

      final melodyNotes = melodyRaw
          .map((item) {
            final m = item as Map<String, dynamic>;
            return AiGameNote(
              pitch: (m['pitch'] as num).toInt(),
              startTime: (m['startTime'] as num).toDouble(),
              duration: (m['duration'] as num).toDouble(),
              isPercussion: false,
            );
          })
          .where((n) =>
              n.pitch >= 55 &&
              n.pitch <= 84 &&
              n.startTime >= 0 &&
              n.startTime < _durationSeconds &&
              n.duration > 0,
          )
          .toList();

      final percussionNotes = (percussionRaw ?? [])
          .map((item) {
            final p = item as Map<String, dynamic>;
            final type = (p['type'] as String?) ?? 'kick';
            return AiGameNote(
              pitch: _percussionMidi(type),
              startTime: (p['startTime'] as num).toDouble(),
              duration: 0.1,
              isPercussion: true,
              percussionType: type,
            );
          })
          .where(
              (n) => n.startTime >= 0 && n.startTime < _durationSeconds,
          )
          .toList();

      return {
        'melody': melodyNotes,
        'percussion': percussionNotes,
        'tempo': tempo,
        'mood': mood,
      };
    } catch (e) {
      debugPrint('[AiMusicService] Parse error: $e');
      return null;
    }
  }

  int _percussionMidi(String type) {
    // GM percussion map
    return switch (type) {
      'kick' => 36,
      'snare' => 38,
      'hh' => 42,
      _ => 36,
    };
  }

  /// Synthesize AI-generated notes to WAV file.
  Future<String?> _synthesizeWav(
    List<AiGameNote> melodyNotes,
    List<AiGameNote> percussionNotes,
    double tempo,
  ) async {
    try {
      final numSamples = (_sampleRate * _durationSeconds).ceil();
      final buffer = Float64List(numSamples);

      // Render melody notes as sine waves
      for (final note in melodyNotes) {
        _renderSineNote(buffer, note);
      }

      // Render percussion
      final rng = Random(42);
      for (final note in percussionNotes) {
        _renderPercussionHit(buffer, note, rng);
      }

      // Soft clipper
      for (var i = 0; i < buffer.length; i++) {
        final x = buffer[i];
        buffer[i] = x * (27 + x * x) / (27 + 9 * x * x) * 0.8;
      }

      // Write WAV
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/ai_music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      final filename =
          'ai_rhythm_${DateTime.now().millisecondsSinceEpoch}.wav';
      final outputPath = '${musicDir.path}/$filename';
      await AudioProcessor.writeWav(outputPath, buffer, _sampleRate);

      return outputPath;
    } catch (e) {
      debugPrint('[AiMusicService] Synthesis error: $e');
      return null;
    }
  }

  void _renderSineNote(Float64List buffer, AiGameNote note) {
    final freq = _midiToFreq(note.pitch);
    final startSample =
        (note.startTime * _sampleRate).round().clamp(0, buffer.length - 1);
    final durSamples = (note.duration * _sampleRate).round();
    final endSample = (startSample + durSamples).clamp(0, buffer.length);

    for (var i = startSample; i < endSample; i++) {
      final t = (i - startSample) / _sampleRate;
      // ADSR envelope
      const attack = 0.02;
      const release = 0.08;
      double env;
      if (t < attack) {
        env = t / attack;
      } else if (t < note.duration - release) {
        env = 0.75;
      } else {
        env = 0.75 * (1.0 - (t - (note.duration - release)) / release);
      }
      if (env <= 0) continue;
      buffer[i] += sin(2 * pi * freq * t) * env * 0.4;
    }
  }

  void _renderPercussionHit(
    Float64List buffer,
    AiGameNote note,
    Random rng,
  ) {
    final startSample =
        (note.startTime * _sampleRate).round().clamp(0, buffer.length - 1);
    final type = note.percussionType ?? 'kick';

    switch (type) {
      case 'kick':
        for (var i = startSample;
            i < buffer.length && (i - startSample) / _sampleRate < 0.2;
            i++) {
          final t = (i - startSample) / _sampleRate;
          final freq = (150 - t * 800).clamp(40, 200);
          buffer[i] += sin(2 * pi * freq * t) * exp(-t * 25) * 0.6;
        }
        break;
      case 'snare':
        for (var i = startSample;
            i < buffer.length && (i - startSample) / _sampleRate < 0.15;
            i++) {
          final t = (i - startSample) / _sampleRate;
          buffer[i] +=
              ((rng.nextDouble() * 2 - 1) * 0.5 + sin(2 * pi * 200 * t) * 0.5) *
                  exp(-t * 35) *
                  0.5;
        }
        break;
      case 'hh':
        var prev = 0.0;
        for (var i = startSample;
            i < buffer.length && (i - startSample) / _sampleRate < 0.08;
            i++) {
          final t = (i - startSample) / _sampleRate;
          final raw = rng.nextDouble() * 2 - 1;
          buffer[i] += ((raw - prev) * 0.5) * exp(-t * 60) * 0.3;
          prev = raw;
        }
        break;
    }
  }

  double _midiToFreq(int midi) => 440.0 * pow(2.0, (midi - 69) / 12.0);

  /// Map AI notes to game tracks based on pitch range.
  /// Used by RhythmGamePage to convert AiGameNotes into game _Notes.
  static int pitchToTrack(int pitch, int trackCount) {
    if (trackCount <= 1) return 0;
    // Dynamic range split based on actual track count
    final rangePerTrack = (84 - 55) / trackCount;
    return ((pitch - 55) / rangePerTrack).floor().clamp(0, trackCount - 1);
  }
}

/// Procedural generation style parameters.
class _StyleCfg {
  final double tempo;
  final double noteInterval;
  final double noteIntervalVariance;
  final double maxNoteDuration;
  final double percussionGrid;
  final int kickEvery;
  final double snareOffset;
  final int snareEvery;
  final double hhProbability;

  const _StyleCfg({
    required this.tempo,
    required this.noteInterval,
    required this.noteIntervalVariance,
    required this.maxNoteDuration,
    required this.percussionGrid,
    required this.kickEvery,
    required this.snareOffset,
    required this.snareEvery,
    required this.hhProbability,
  });
}
