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
}
