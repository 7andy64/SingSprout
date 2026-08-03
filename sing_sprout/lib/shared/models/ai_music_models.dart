/// AI-generated music note used for rhythm game gameplay.
class AiGameNote {
  final int pitch; // MIDI pitch 0-127
  final double startTime; // seconds from song start
  final double duration; // seconds
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
  String toString() =>
      'AiGameNote(pitch=$pitch, t=$startTime, dur=$duration)';
}

/// Result of AI music generation — ready for rhythm game consumption.
class AiMusicResult {
  final String wavPath; // local WAV file path
  final List<AiGameNote> notes; // melody + percussion notes
  final double tempo; // BPM
  final String mood; // mood description in Chinese
  final int totalDurationSeconds; // track duration

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
  happy, // 😄 欢快
  calm, // 🌙 舒缓
  energetic, // ⚡ 动感
  electronic, // 🎹 电子
}

/// Human-readable labels for each style.
extension AiMusicStyleLabel on AiMusicStyle {
  String get label => switch (this) {
        AiMusicStyle.happy => '欢快',
        AiMusicStyle.calm => '舒缓',
        AiMusicStyle.energetic => '动感',
        AiMusicStyle.electronic => '电子',
      };

  String get emoji => switch (this) {
        AiMusicStyle.happy => '😄',
        AiMusicStyle.calm => '🌙',
        AiMusicStyle.energetic => '⚡',
        AiMusicStyle.electronic => '🎹',
      };
}
