import 'package:uuid/uuid.dart';

/// 声音明信片模型（发件箱）
class VoiceCard {
  final String id;
  final String workId;
  final String senderId;
  final String? recipientId;
  final String? audioPath;
  final String? textContent;
  final String? coverUrl;
  final String? greetingAudioPath;
  final String? greetingText;
  final DateTime createdAt;

  const VoiceCard({
    required this.id,
    required this.workId,
    required this.senderId,
    this.recipientId,
    this.audioPath,
    this.textContent,
    this.coverUrl,
    this.greetingAudioPath,
    this.greetingText,
    required this.createdAt,
  });

  factory VoiceCard.send({
    required String senderId,
    String? recipientId,
    String? workId,
    String? audioPath,
    String? textContent,
    String? coverUrl,
    String? greetingAudioPath,
    String? greetingText,
  }) {
    final now = DateTime.now();
    return VoiceCard(
      id: const Uuid().v4(),
      workId: workId ?? '',
      senderId: senderId,
      recipientId: recipientId,
      audioPath: audioPath,
      textContent: textContent,
      coverUrl: coverUrl,
      greetingAudioPath: greetingAudioPath,
      greetingText: greetingText,
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'work_id': workId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'audio_path': audioPath,
        'text_content': textContent,
        'cover_url': coverUrl,
        'greeting_audio_path': greetingAudioPath,
        'greeting_text': greetingText,
        'created_at': createdAt.toIso8601String(),
      };

  factory VoiceCard.fromJson(Map<String, dynamic> json) => VoiceCard(
        id: json['id'] as String,
        workId: json['work_id'] as String? ?? json['workId'] as String,
        senderId: json['sender_id'] as String? ?? json['senderId'] as String,
        recipientId: json['recipient_id'] as String?,
        audioPath: json['audio_path'] as String?,
        textContent: json['text_content'] as String?,
        coverUrl: json['cover_url'] as String?,
        greetingAudioPath: json['greeting_audio_path'] as String?,
        greetingText: json['greeting_text'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  VoiceCard copyWith({
    String? id,
    String? workId,
    String? senderId,
    String? recipientId,
    String? audioPath,
    String? textContent,
    String? coverUrl,
    String? greetingAudioPath,
    String? greetingText,
    DateTime? createdAt,
  }) {
    return VoiceCard(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      audioPath: audioPath ?? this.audioPath,
      textContent: textContent ?? this.textContent,
      coverUrl: coverUrl ?? this.coverUrl,
      greetingAudioPath: greetingAudioPath ?? this.greetingAudioPath,
      greetingText: greetingText ?? this.greetingText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
