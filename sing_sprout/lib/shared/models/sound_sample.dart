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
        'audio_path': audioPath,
        'type': type.name,
        'bpm': bpm,
        'pitch_sequence': pitchSequence,
        'timbre_feature': timbreFeature,
        'recommended_use': recommendedUse,
        'is_public': isPublic ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  SoundSample copyWith({
    String? name,
    String? audioPath,
    SoundType? type,
    double? bpm,
    String? pitchSequence,
    String? timbreFeature,
    String? recommendedUse,
    bool? isPublic,
  }) {
    return SoundSample(
      id: id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      type: type ?? this.type,
      bpm: bpm ?? this.bpm,
      pitchSequence: pitchSequence ?? this.pitchSequence,
      timbreFeature: timbreFeature ?? this.timbreFeature,
      recommendedUse: recommendedUse ?? this.recommendedUse,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
    );
  }

  factory SoundSample.fromJson(Map<String, dynamic> json) => SoundSample(
        id: json['id'] as String,
        name: json['name'] as String,
        audioPath: json['audio_path'] as String,
        type: SoundType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => SoundType.unknown,
        ),
        bpm: (json['bpm'] as num?)?.toDouble(),
        pitchSequence: json['pitch_sequence'] as String?,
        timbreFeature: json['timbre_feature'] as String?,
        recommendedUse: json['recommended_use'] as String?,
        isPublic: (json['is_public'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
