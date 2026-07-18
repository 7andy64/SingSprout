import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';

/// 声音样本模型 — 田野声音实验室产出
class SoundSample {
  final String id;
  final String name;
  final String audioPath;
  final SoundType type;
  final double? bpm;
  final String? pitchSequence;   // 音高序列描述
  final String? timbreFeature;   // 音色特征
  final String? recommendedUse;  // AI 推荐用途
  final bool isPublic;           // 是否加入公共声音库
  final DateTime createdAt;

  const SoundSample({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.type,
    this.bpm,
    this.pitchSequence,
    this.timbreFeature,
    this.recommendedUse,
    this.isPublic = false,
    required this.createdAt,
  });

  factory SoundSample.create({
    required String name,
    required String audioPath,
    required SoundType type,
    double? bpm,
    String? pitchSequence,
    String? timbreFeature,
  }) {
    return SoundSample(
      id: const Uuid().v4(),
      name: name,
      audioPath: audioPath,
      type: type,
      bpm: bpm,
      pitchSequence: pitchSequence,
      timbreFeature: timbreFeature,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioPath': audioPath,
        'type': type.name,
        'bpm': bpm,
        'pitchSequence': pitchSequence,
        'timbreFeature': timbreFeature,
        'recommendedUse': recommendedUse,
        'isPublic': isPublic,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SoundSample.fromJson(Map<String, dynamic> json) => SoundSample(
        id: json['id'] as String,
        name: json['name'] as String,
        audioPath: json['audioPath'] as String,
        type: SoundType.values.firstWhere((e) => e.name == json['type']),
        bpm: (json['bpm'] as num?)?.toDouble(),
        pitchSequence: json['pitchSequence'] as String?,
        timbreFeature: json['timbreFeature'] as String?,
        recommendedUse: json['recommendedUse'] as String?,
        isPublic: json['isPublic'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
