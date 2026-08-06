# AI 节奏游戏 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有节奏游戏基础上增加"AI 创作模式"——用户选择音乐风格，AI 生成音乐数据，WavSynthesizer 合成音频，音符映射为游戏下落谱面。

**Architecture:** 新增 `AiMusicService` 调用 DashScope qwen-plus 生成音乐 JSON，解析后用现有 `WavSynthesizer` 合成 WAV 音频。新增 `AiMusicResult` / `AiGameNote` 数据模型。`RhythmGamePage` 新增模式选择（经典/AI）UI 状态，`RhythmTribePage` 入口微调。

**Tech Stack:** Flutter 3.16+, Dart 3.2+, DashScope qwen-plus, 现有 WavSynthesizer, audioplayers ^5.2.1

## Global Constraints

- 经典模式逻辑不改动
- AI 模式奖励与经典模式一致（不额外改动经济系统）
- 离线优先：AI 调用失败时降级到经典模式
- 儿童友好：文案简洁温暖，错误提示不吓人

---

## File Structure

```
sing_sprout/lib/
├── shared/
│   ├── models/
│   │   └── ai_music_models.dart          # NEW: AiGameNote, AiMusicResult
│   └── services/
│       └── ai_music_service.dart         # NEW: AI music generation + WAV synthesis
└── features/rhythm_tribe/
    ├── rhythm_game_page.dart             # MODIFY: mode selection, AI flow, audio playback
    └── rhythm_tribe_page.dart            # MODIFY: entry card updated
```

---

### Task 1: Create data models (`ai_music_models.dart`)

**Files:**
- Create: `sing_sprout/lib/shared/models/ai_music_models.dart`

**Interfaces:**
- Produces: `AiGameNote` class (pitch, startTime, duration, isPercussion, percussionType), `AiMusicResult` class (wavPath, notes, tempo, mood), `AiMusicStyle` enum (happy, calm, energetic, electronic)

- [ ] **Step 1: Write the model file**

```dart
/// AI-generated music note used for rhythm game gameplay.
class AiGameNote {
  final int pitch;           // MIDI pitch 0-127
  final double startTime;    // seconds from song start
  final double duration;     // seconds
  final bool isPercussion;
  final String? percussionType; // "kick" | "snare" | "hh" | null

  const AiGameNote({
    required this.pitch,
    required this.startTime,
    required this.duration,
    this.isPercussion = false,
    this.percussionType,
  });

  Map<String, dynamic> toJson() => {
    'pitch': pitch,
    'startTime': startTime,
    'duration': duration,
    'isPercussion': isPercussion,
    'percussionType': percussionType,
  };

  factory AiGameNote.fromJson(Map<String, dynamic> json) => AiGameNote(
    pitch: (json['pitch'] as num).toInt(),
    startTime: (json['startTime'] as num).toDouble(),
    duration: (json['duration'] as num).toDouble(),
    isPercussion: json['isPercussion'] as bool? ?? false,
    percussionType: json['percussionType'] as String?,
  );

  @override
  String toString() => 'AiGameNote(pitch=$pitch, t=$startTime, dur=$duration)';
}

/// Result of AI music generation — ready for rhythm game consumption.
class AiMusicResult {
  final String wavPath;              // local WAV file path
  final List<AiGameNote> notes;      // melody + percussion notes
  final double tempo;                // BPM
  final String mood;                 // mood description in Chinese
  final int totalDurationSeconds;    // track duration

  const AiMusicResult({
    required this.wavPath,
    required this.notes,
    required this.tempo,
    required this.mood,
    this.totalDurationSeconds = 30,
  });
}

/// Music style tags for AI generation.
enum AiMusicStyle {
  happy,       // 😄 欢快
  calm,        // 🌙 舒缓
  energetic,   // ⚡ 动感
  electronic,  // 🎹 电子
}

/// Human-readable labels for each style.
extension AiMusicStyleLabel on AiMusicStyle {
  String get label => switch (this) {
    AiMusicStyle.happy      => '欢快',
    AiMusicStyle.calm        => '舒缓',
    AiMusicStyle.energetic   => '动感',
    AiMusicStyle.electronic  => '电子',
  };

  String get emoji => switch (this) {
    AiMusicStyle.happy      => '😄',
    AiMusicStyle.calm        => '🌙',
    AiMusicStyle.energetic   => '⚡',
    AiMusicStyle.electronic  => '🎹',
  };
}
```

- [ ] **Step 2: Commit**

```bash
cd sing_sprout && git add lib/shared/models/ai_music_models.dart && git commit -m "feat: add AiGameNote and AiMusicResult models"
```

---

### Task 2: Create AiMusicService

**Files:**
- Create: `sing_sprout/lib/shared/services/ai_music_service.dart`

**Interfaces:**
- Consumes: `DashScopeService().chatCompletion()` (existing), `WavSynthesizer` (existing), `AiGameNote`, `AiMusicResult`, `AiMusicStyle` from Task 1
- Produces: `AiMusicService().generateGameMusic(AiMusicStyle style)` → `Future<AiMusicResult?>`

- [ ] **Step 1: Write the service file**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_music_models.dart';
import 'dash_scope_service.dart';
import 'wav_synthesizer.dart';
import 'audio_processor.dart';

/// Generates AI music for the rhythm game.
///
/// Calls DashScope qwen-plus to compose melody + percussion as JSON,
/// then synthesizes the result to WAV via [WavSynthesizer].
class AiMusicService {
  static final AiMusicService _instance = AiMusicService._();
  factory AiMusicService() => _instance;
  AiMusicService._();

  static const _sampleRate = 22050;
  static const _durationSeconds = 30;

  /// Generate a complete music track for the rhythm game.
  ///
  /// Returns null if AI is unavailable, API key missing, or generation fails.
  Future<AiMusicResult?> generateGameMusic(AiMusicStyle style) async {
    final dashScope = DashScopeService();
    final isConfigured = await dashScope.isConfigured;
    if (!isConfigured) {
      debugPrint('[AiMusicService] DashScope not configured');
      return null;
    }

    // 1. Call AI to generate music data
    final rawJson = await dashScope.chatCompletion(
      systemPrompt: _systemPrompt(style),
      userMessage: '请为节奏游戏创作一段$_durationSeconds秒的${style.label}风格音乐。',
      temperature: 0.85,
      maxTokens: 3000,
    );

    if (rawJson == null) {
      debugPrint('[AiMusicService] AI returned null');
      return null;
    }

    // 2. Parse JSON
    final parsed = _parseMusicJson(rawJson, style);
    if (parsed == null) {
      debugPrint('[AiMusicService] Failed to parse AI response');
      return null;
    }

    final melodyNotes = parsed['melody'] as List<AiGameNote>;
    final percussionNotes = parsed['percussion'] as List<AiGameNote>;
    final tempo = parsed['tempo'] as double;
    final mood = parsed['mood'] as String;

    // 3. Synthesize WAV
    final wavPath = await _synthesizeWav(melodyNotes, percussionNotes, tempo);
    if (wavPath == null) {
      debugPrint('[AiMusicService] WAV synthesis failed');
      return null;
    }

    // 4. Merge notes for the game (melody + percussion, sorted by time)
    final allNotes = [...melodyNotes, ...percussionNotes]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return AiMusicResult(
      wavPath: wavPath,
      notes: allNotes,
      tempo: tempo,
      mood: mood,
    );
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
- 输出至少80个旋律音符和60个打击乐音符
''';
  }

  /// Parse AI response JSON into melody + percussion notes.
  Map<String, dynamic>? _parseMusicJson(String raw, AiMusicStyle style) {
    try {
      var jsonStr = raw.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
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

      final melodyNotes = melodyRaw.map((item) {
        final m = item as Map<String, dynamic>;
        return AiGameNote(
          pitch: (m['pitch'] as num).toInt(),
          startTime: (m['startTime'] as num).toDouble(),
          duration: (m['duration'] as num).toDouble(),
          isPercussion: false,
        );
      }).where((n) =>
        n.pitch >= 55 && n.pitch <= 84 &&
        n.startTime >= 0 && n.startTime < _durationSeconds &&
        n.duration > 0
      ).toList();

      final percussionNotes = (percussionRaw ?? []).map((item) {
        final p = item as Map<String, dynamic>;
        final type = (p['type'] as String?) ?? 'kick';
        return AiGameNote(
          pitch: _percussionMidi(type),
          startTime: (p['startTime'] as num).toDouble(),
          duration: 0.1,
          isPercussion: true,
          percussionType: type,
        );
      }).where((n) => n.startTime >= 0 && n.startTime < _durationSeconds).toList();

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
      'kick'  => 36,
      'snare' => 38,
      'hh'    => 42,
      _       => 36,
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
      final filename = 'ai_rhythm_${DateTime.now().millisecondsSinceEpoch}.wav';
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
    final startSample = (note.startTime * _sampleRate).round().clamp(0, buffer.length - 1);
    final durSamples = (note.duration * _sampleRate).round();
    final endSample = (startSample + durSamples).clamp(0, buffer.length);

    for (var i = startSample; i < endSample; i++) {
      final t = (i - startSample) / _sampleRate;
      // ADSR envelope
      final attack = 0.02;
      final release = 0.08;
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

  void _renderPercussionHit(Float64List buffer, AiGameNote note, Random rng) {
    final startSample = (note.startTime * _sampleRate).round().clamp(0, buffer.length - 1);
    final type = note.percussionType ?? 'kick';

    switch (type) {
      case 'kick':
        for (var i = startSample; i < buffer.length && (i - startSample) / _sampleRate < 0.2; i++) {
          final t = (i - startSample) / _sampleRate;
          final freq = (150 - t * 800).clamp(40, 200);
          buffer[i] += sin(2 * pi * freq * t) * exp(-t * 25) * 0.6;
        }
        break;
      case 'snare':
        for (var i = startSample; i < buffer.length && (i - startSample) / _sampleRate < 0.15; i++) {
          final t = (i - startSample) / _sampleRate;
          buffer[i] += ((rng.nextDouble() * 2 - 1) * 0.5 + sin(2 * pi * 200 * t) * 0.5) * exp(-t * 35) * 0.5;
        }
        break;
      case 'hh':
        var prev = 0.0;
        for (var i = startSample; i < buffer.length && (i - startSample) / _sampleRate < 0.08; i++) {
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
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd sing_sprout && flutter analyze lib/shared/services/ai_music_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
cd sing_sprout && git add lib/shared/services/ai_music_service.dart && git commit -m "feat: add AiMusicService for AI rhythm game music generation"
```

---

### Task 3: Modify RhythmGamePage — add AI mode

**Files:**
- Modify: `sing_sprout/lib/features/rhythm_tribe/rhythm_game_page.dart`

**Interfaces:**
- Consumes: `AiMusicService`, `AiMusicResult`, `AiGameNote`, `AiMusicStyle` from Tasks 1-2; existing `_Note`, `_DifficultyConfig`, `_GamePhase` within the file
- Produces: Updated `RhythmGamePage` with mode selection (classic/AI), style picker, loading state, AI-powered gameplay with background music playback

- [ ] **Step 1: Add imports and new enums at top of file**

```dart
// Add these imports after existing imports:
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../shared/models/ai_music_models.dart';
import '../../shared/services/ai_music_service.dart';

// Add new enums after existing _GamePhase:
enum _GameMode { classic, ai }

enum _AiPhase { idle, selectingStyle, generating, ready }
```

- [ ] **Step 2: Add AI-related fields to _RhythmGamePageState**

Add these fields inside `_RhythmGamePageState` (after existing field declarations, before initState):

```dart
  // ── AI Mode ──
  _GameMode _gameMode = _GameMode.classic;
  _AiPhase _aiPhase = _AiPhase.idle;
  AiMusicStyle? _selectedStyle;
  AiMusicResult? _aiResult;
  String? _aiError;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioLoaded = false;
  
  // Store original BPM config for AI mode (tempo comes from AI, not difficulty config)
  double _effectiveBpm = 120;
```

- [ ] **Step 3: Update _startGame to handle AI mode**

Replace the `_startGame` method:

```dart
  void _startGame() {
    final economy = context.read<EconomyProvider>();
    if (economy.isDailyLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天的小松果们已经睡觉啦，明天再来吧 🌰💤')),
      );
      return;
    }

    _cfg = _DifficultyConfig.of(_difficulty);

    if (_gameMode == _GameMode.ai && _aiResult != null) {
      _startAiGame();
    } else {
      _startClassicGame();
    }
  }

  void _startClassicGame() {
    _effectiveBpm = _cfg.bpm;
    _generateBeatGrid();
    _generateNotes();
    _beginCountdown();
  }

  void _startAiGame() {
    _effectiveBpm = _aiResult!.tempo;
    // Generate beat grid from AI tempo
    _beatTimes.clear();
    final beatInterval = 60.0 / _effectiveBpm;
    for (double t = 0; t <= gameDuration + 2; t += beatInterval) {
      _beatTimes.add(t);
    }
    // Map AI notes to game notes
    _generateAiNotes();
    _beginCountdown();
  }

  void _generateAiNotes() {
    _notes.clear();
    final result = _aiResult!;
    for (final aiNote in result.notes) {
      if (aiNote.startTime >= gameDuration - 1.0) continue;
      final track = AiMusicService.pitchToTrack(aiNote.pitch, _cfg.trackCount);
      _notes.add(_Note(time: aiNote.startTime, track: track));
    }
    _notes.sort((a, b) => a.time.compareTo(b.time));
  }

  void _beginCountdown() {
    // Clean up previous state
    _controller.reset();
    _countdownTimer?.cancel();
    _hitNotes.clear();
    _missedNotes.clear();
    _particles.clear();
    _hitTexts.clear();
    _hitFlashes.clear();
    _trackShakes.clear();
    _screenFlash = 0;

    setState(() {
      _phase = _GamePhase.countdown;
      _countdownValue = 3;
      _elapsed = 0;
      _score = 0;
      _perfectCount = 0;
      _goodCount = 0;
      _missCount = 0;
      _combo = 0;
      _maxCombo = 0;
      _coinReward = 0;
    });

    _runCountdown();
  }
```

- [ ] **Step 4: Modify _runCountdown to start audio in AI mode**

Replace the countdown timer callback inside `_runCountdown`:

```dart
  void _runCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = _countdownValue - 1;
      if (next < 0) {
        timer.cancel();
        setState(() { _phase = _GamePhase.playing; });
        _controller.forward();
        // Start background music for AI mode
        if (_gameMode == _GameMode.ai && _aiResult != null) {
          _playAiMusic();
        }
      } else {
        setState(() { _countdownValue = next; });
      }
    });
  }

  Future<void> _playAiMusic() async {
    try {
      await _audioPlayer.play(DeviceFileSource(_aiResult!.wavPath));
      _audioLoaded = true;
    } catch (e) {
      debugPrint('[RhythmGame] Audio playback failed: $e');
    }
  }

  Future<void> _stopAiMusic() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _audioLoaded = false;
  }
```

- [ ] **Step 5: Update _finishGame and _quitGame to stop audio**

In `_finishGame`, add `_stopAiMusic();` at the beginning.
In `_quitGame`, add `_stopAiMusic();` before state change.

Add this to `_finishGame` (as the first line):
```dart
    _stopAiMusic();
```

Add this to `_quitGame` (before the setState):
```dart
    _stopAiMusic();
```

- [ ] **Step 6: Add dispose cleanup**

In `dispose()`, add:
```dart
    _audioPlayer.dispose();
```

- [ ] **Step 7: Add AI mode UI methods**

Add these methods to `_RhythmGamePageState`:

```dart
  /// Start AI generation flow — show style picker.
  void _enterAiMode() {
    setState(() {
      _gameMode = _GameMode.ai;
      _aiPhase = _AiPhase.selectingStyle;
      _aiError = null;
    });
  }

  /// User selected a style — start generation.
  Future<void> _selectStyle(AiMusicStyle style) async {
    setState(() {
      _selectedStyle = style;
      _aiPhase = _AiPhase.generating;
    });

    final result = await AiMusicService().generateGameMusic(style);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _aiResult = result;
        _aiPhase = _AiPhase.ready;
      });
      // Auto-start the game
      _startGame();
    } else {
      setState(() {
        _aiError = 'AI 音乐家正在休息，先试试经典模式吧 🌱';
        _aiPhase = _AiPhase.idle;
      });
    }
  }

  /// Go back to mode selection.
  void _backToModeSelect() {
    _stopAiMusic();
    setState(() {
      _gameMode = _GameMode.classic;
      _aiPhase = _AiPhase.idle;
      _aiResult = null;
      _selectedStyle = null;
      _aiError = null;
    });
  }
```

- [ ] **Step 8: Modify the idle state build to show mode selection**

In the `build` method, replace the `_GamePhase.idle` case to show mode selection when not already in AI flow, and AI screens when in AI mode:

```dart
      case _GamePhase.idle:
        if (_aiPhase == _AiPhase.selectingStyle) {
          return Scaffold(body: _AiStylePicker(
            onSelected: _selectStyle,
            onBack: _backToModeSelect,
          ));
        }
        if (_aiPhase == _AiPhase.generating) {
          return Scaffold(body: _AiGeneratingScreen(
            style: _selectedStyle!,
          ));
        }
        if (_aiPhase == _AiPhase.idle && _aiError != null) {
          // Show error then return to start screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_aiError!), duration: const Duration(seconds: 3)),
            );
            setState(() { _aiError = null; });
          });
        }
        return Scaffold(
          body: _StartScreen(
            selectedDifficulty: _difficulty,
            onDifficultyChanged: (d) => setState(() { _difficulty = d; }),
            onStart: _startGame,
            onAiMode: _enterAiMode,
          ),
        );
```

- [ ] **Step 9: Update _StartScreen to show AI mode button**

Add `onAiMode` parameter to `_StartScreen` constructor and add an AI mode button after the "开始游戏" button:

```dart
// Add to _StartScreen class:
  final VoidCallback onAiMode;

// In constructor, add: required this.onAiMode,

// After the existing FilledButton "开始游戏", add:
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAiMode,
                icon: const Text('🤖', style: TextStyle(fontSize: 20)),
                label: const Text('AI 创作音乐'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
```

- [ ] **Step 10: Add AI UI widget classes at end of file**

Add these widgets before the `_StatRow` class at the bottom:

```dart
// ═══════════════════════════════════════════════════════════════
// AI 风格选择界面
// ═══════════════════════════════════════════════════════════════

class _AiStylePicker extends StatelessWidget {
  final Function(AiMusicStyle) onSelected;
  final VoidCallback onBack;

  const _AiStylePicker({required this.onSelected, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖🎵', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('AI 为你创作音乐',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('选一种风格，AI 会为你生成\n独一无二的音乐和节奏',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              ...AiMusicStyle.values.map((style) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StyleCard(
                  style: style,
                  onTap: () => onSelected(style),
                ),
              )),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onBack,
                child: const Text('返回经典模式'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final AiMusicStyle style;
  final VoidCallback onTap;

  const _StyleCard({required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final description = switch (style) {
      AiMusicStyle.happy      => '明亮活泼 · 大调旋律 · 跳跃节奏',
      AiMusicStyle.calm        => '温柔宁静 · 摇篮曲风 · 舒缓心情',
      AiMusicStyle.energetic   => '强烈动感 · 电子舞曲 · 附点节奏',
      AiMusicStyle.electronic  => '现代合成 · 琶音上行 · 电子音色',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Text(style.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AI 生成中加载界面
// ═══════════════════════════════════════════════════════════════

class _AiGeneratingScreen extends StatefulWidget {
  final AiMusicStyle style;
  const _AiGeneratingScreen({required this.style});

  @override
  State<_AiGeneratingScreen> createState() => _AiGeneratingScreenState();
}

class _AiGeneratingScreenState extends State<_AiGeneratingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<String> _messages = const [
    'AI 正在构思旋律...',
    '正在编排节奏...',
    '即将完成...',
  ];
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Cycle through messages
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _msgIndex = (_msgIndex + 1) % _messages.length; });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.style.emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animCtrl.value * 2 * 3.14159,
                  child: const Text('🎵', style: TextStyle(fontSize: 40)),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(_messages[_msgIndex],
                style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('${widget.style.label}风格 · 30秒音乐',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 11: Add the AnimatedBuilder import and fix the animation builder**

Since `AnimatedBuilder` is from Flutter, make sure it's imported. The correct widget is `AnimatedBuilder` which is available from Flutter's material library. If not recognized, use `ListenableBuilder`:

```dart
// If AnimatedBuilder is not recognized, replace with:
ListenableBuilder(
  listenable: _animCtrl,
  builder: (context, child) {
    return Transform.rotate(
      angle: _animCtrl.value * 2 * 3.14159,
      child: const Text('🎵', style: TextStyle(fontSize: 40)),
    );
  },
),
```

- [ ] **Step 12: Verify the file compiles**

Run: `cd sing_sprout && flutter analyze lib/features/rhythm_tribe/rhythm_game_page.dart`
Expected: No errors (or only pre-existing warnings)

- [ ] **Step 13: Commit**

```bash
cd sing_sprout && git add lib/features/rhythm_tribe/rhythm_game_page.dart && git commit -m "feat: add AI mode to rhythm game with style selection and auto-generation"
```

---

### Task 4: Update RhythmTribePage entry card

**Files:**
- Modify: `sing_sprout/lib/features/rhythm_tribe/rhythm_tribe_page.dart`

**Interfaces:**
- Consumes: Existing `RhythmTribePage`, `_GameEntryCard`
- Produces: Updated rhythm game entry card with AI mode hint

- [ ] **Step 1: Update the rhythm game entry card subtitle**

In `rhythm_tribe_page.dart`, find the `_GameEntryCard` for rhythm game (emoji '🥁') and update:

```dart
// Change from:
subtitle: '跟着节拍点击，比比谁更准',
// To:
subtitle: '经典节奏挑战 · AI 为你创作音乐',
```

- [ ] **Step 2: Commit**

```bash
cd sing_sprout && git add lib/features/rhythm_tribe/rhythm_tribe_page.dart && git commit -m "feat: update rhythm game entry to mention AI mode"
```

---

### Task 5: Test the AI music service

**Files:**
- Create: `sing_sprout/test/ai_music_service_test.dart`

**Interfaces:**
- Consumes: `AiMusicService`, `AiMusicStyle`, `AiGameNote`, `AiMusicResult` from Tasks 1-2

- [ ] **Step 1: Write tests for data models and utility methods**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_sprout/shared/models/ai_music_models.dart';
import 'package:sing_sprout/shared/services/ai_music_service.dart';

void main() {
  group('AiGameNote', () {
    test('fromJson and toJson roundtrip', () {
      final original = AiGameNote(
        pitch: 64,
        startTime: 1.5,
        duration: 0.5,
        isPercussion: false,
      );
      final json = original.toJson();
      final restored = AiGameNote.fromJson(json);
      expect(restored.pitch, 64);
      expect(restored.startTime, 1.5);
      expect(restored.duration, 0.5);
      expect(restored.isPercussion, false);
    });

    test('percussion note fromJson', () {
      final json = {
        'pitch': 36,
        'startTime': 0.0,
        'duration': 0.1,
        'isPercussion': true,
        'percussionType': 'kick',
      };
      final note = AiGameNote.fromJson(json);
      expect(note.isPercussion, true);
      expect(note.percussionType, 'kick');
    });
  });

  group('AiMusicStyle', () {
    test('all styles have label and emoji', () {
      for (final style in AiMusicStyle.values) {
        expect(style.label, isNotEmpty);
        expect(style.emoji, isNotEmpty);
      }
    });

    test('labels are all unique', () {
      final labels = AiMusicStyle.values.map((s) => s.label).toSet();
      expect(labels.length, AiMusicStyle.values.length);
    });
  });

  group('pitchToTrack', () {
    test('maps low pitch to track 0', () {
      expect(AiMusicService.pitchToTrack(55, 3), 0);
      expect(AiMusicService.pitchToTrack(60, 3), 0);
    });

    test('maps mid pitch to track 1', () {
      expect(AiMusicService.pitchToTrack(65, 3), 1);
      expect(AiMusicService.pitchToTrack(70, 3), 1);
    });

    test('maps high pitch to track 2', () {
      expect(AiMusicService.pitchToTrack(75, 3), 2);
      expect(AiMusicService.pitchToTrack(84, 3), 2);
    });

    test('adapts to track count', () {
      expect(AiMusicService.pitchToTrack(60, 2), 0);
      expect(AiMusicService.pitchToTrack(75, 2), 1);
      expect(AiMusicService.pitchToTrack(60, 4), 0);
      expect(AiMusicService.pitchToTrack(84, 4), 3);
    });

    test('clamps output to valid range', () {
      expect(AiMusicService.pitchToTrack(0, 3), 0);
      expect(AiMusicService.pitchToTrack(127, 3), 2);
    });
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `cd sing_sprout && flutter test test/ai_music_service_test.dart`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
cd sing_sprout && git add test/ai_music_service_test.dart && git commit -m "test: add unit tests for AI music models and pitchToTrack"
```

---
