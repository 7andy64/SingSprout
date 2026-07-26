import 'package:uuid/uuid.dart';

/// 声音明信片模型
class VoiceCard {
  final String id;
  final String workId;
  final String senderId;
  final String? recipientId;
  final String? audioPath;
  final String? textContent;
  final String? coverUrl;
  final String? replyToId;
  final VoiceCardDirection direction;
  final DateTime createdAt;
  final DateTime? readAt;

  const VoiceCard({
    required this.id,
    required this.workId,
    required this.senderId,
    this.recipientId,
    this.audioPath,
    this.textContent,
    this.coverUrl,
    this.replyToId,
    required this.direction,
    required this.createdAt,
    this.readAt,
  });

  factory VoiceCard.send({
    required String senderId,
    String? recipientId,
    String? workId,
    String? audioPath,
    String? textContent,
    String? coverUrl,
    String? replyToId,
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
      replyToId: replyToId,
      direction: VoiceCardDirection.sent,
      createdAt: now,
    );
  }

  VoiceCard copyWith({
    String? id,
    String? workId,
    String? senderId,
    String? recipientId,
    String? audioPath,
    String? textContent,
    String? coverUrl,
    String? replyToId,
    VoiceCardDirection? direction,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return VoiceCard(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      audioPath: audioPath ?? this.audioPath,
      textContent: textContent ?? this.textContent,
      coverUrl: coverUrl ?? this.coverUrl,
      replyToId: replyToId ?? this.replyToId,
      direction: direction ?? this.direction,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

enum VoiceCardDirection { sent, received }
