import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';

/// 音乐作品模型
class MusicWork {
  final String id;
  final String title;
  final String audioPath;
  final String? coverPath;
  final StyleSeed styleSeed;
  final MoodColor? moodSticker;
  final String? note;
  final Duration duration;
  final bool isFavorite;
  final bool isEncrypted;
  final bool isPrivate;    // 私密作品，需密码访问
  final String sourceModule; // humming_garden / mood_radio / field_lab
  final DateTime createdAt;
  final DateTime updatedAt;

  const MusicWork({
    required this.id,
    required this.title,
    required this.audioPath,
    this.coverPath,
    required this.styleSeed,
    this.moodSticker,
    this.note,
    required this.duration,
    this.isFavorite = false,
    this.isEncrypted = true,
    this.isPrivate = false,
    this.sourceModule = 'humming_garden',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MusicWork.create({
    required String title,
    required String audioPath,
    StyleSeed styleSeed = StyleSeed.morningDew,
    MoodColor? moodSticker,
    String? note,
    required Duration duration,
    String sourceModule = 'humming_garden',
  }) {
    final now = DateTime.now();
    final id = const Uuid().v4();
    return MusicWork(
      id: id,
      title: title,
      audioPath: audioPath,
      styleSeed: styleSeed,
      moodSticker: moodSticker,
      note: note,
      duration: duration,
      sourceModule: sourceModule,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'audio_path': audioPath,
        'cover_path': coverPath,
        'style_seed': styleSeed.name,
        'mood_color': moodSticker?.name,
        'note': note,
        'duration_ms': duration.inMilliseconds,
        'is_favorite': isFavorite ? 1 : 0,
        'is_encrypted': isEncrypted ? 1 : 0,
        'is_private': isPrivate ? 1 : 0,
        'source_module': sourceModule,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MusicWork.fromJson(Map<String, dynamic> json) => MusicWork(
        id: json['id'] as String,
        title: json['title'] as String,
        audioPath: json['audio_path'] as String,
        coverPath: json['cover_path'] as String?,
        styleSeed: _parseEnum(StyleSeed.values, json['style_seed'] as String?),
        moodSticker:
            json['mood_color'] != null ? _parseEnum(MoodColor.values, json['mood_color'] as String?) : null,
        note: json['note'] as String?,
        duration: Duration(milliseconds: json['duration_ms'] as int? ?? 0),
        isFavorite: (json['is_favorite'] as int? ?? 0) == 1,
        isEncrypted: (json['is_encrypted'] as int? ?? 1) == 1,
        isPrivate: (json['is_private'] as int? ?? 0) == 1,
        sourceModule: json['source_module'] as String? ?? 'humming_garden',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  MusicWork copyWith({
    String? title,
    String? audioPath,
    String? coverPath,
    StyleSeed? styleSeed,
    MoodColor? moodSticker,
    String? note,
    Duration? duration,
    bool? isFavorite,
    bool? isEncrypted,
    bool? isPrivate,
    String? sourceModule,
  }) {
    return MusicWork(
      id: id,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      coverPath: coverPath ?? this.coverPath,
      styleSeed: styleSeed ?? this.styleSeed,
      moodSticker: moodSticker ?? this.moodSticker,
      note: note ?? this.note,
      duration: duration ?? this.duration,
      isFavorite: isFavorite ?? this.isFavorite,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isPrivate: isPrivate ?? this.isPrivate,
      sourceModule: sourceModule ?? this.sourceModule,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static T _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return values.first;
    return values.firstWhere((e) => e.name == name, orElse: () => values.first);
  }
}
