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
  final bool isEncrypted;
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
    this.isEncrypted = true,
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
  }) {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    return MusicWork(
      id: id,
      title: title,
      audioPath: audioPath,
      styleSeed: styleSeed,
      moodSticker: moodSticker,
      note: note,
      duration: duration,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'audioPath': audioPath,
        'coverPath': coverPath,
        'styleSeed': styleSeed.name,
        'moodSticker': moodSticker?.name,
        'note': note,
        'durationMs': duration.inMilliseconds,
        'isEncrypted': isEncrypted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MusicWork.fromJson(Map<String, dynamic> json) => MusicWork(
        id: json['id'] as String,
        title: json['title'] as String,
        audioPath: json['audioPath'] as String,
        coverPath: json['coverPath'] as String?,
        styleSeed: StyleSeed.values.byName(json['styleSeed'] as String),
        moodSticker: json['moodSticker'] != null
            ? MoodColor.values.byName(json['moodSticker'] as String)
            : null,
        note: json['note'] as String?,
        duration: Duration(milliseconds: json['durationMs'] as int),
        isEncrypted: json['isEncrypted'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
