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

  /// 是否未读（收到的卡片且未阅读）
  bool get isUnread =>
      direction == VoiceCardDirection.received && readAt == null;

  /// 创建一张收到的回信
  factory VoiceCard.received({
    required String id,
    required String senderId,
    required String workId,
    String? textContent,
    String? audioPath,
    String? coverUrl,
    String? replyToId,
    required DateTime createdAt,
  }) {
    return VoiceCard(
      id: id,
      workId: workId,
      senderId: senderId,
      textContent: textContent,
      audioPath: audioPath,
      coverUrl: coverUrl,
      replyToId: replyToId,
      direction: VoiceCardDirection.received,
      createdAt: createdAt,
      readAt: null,
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
        'reply_to_id': replyToId,
        'direction': direction.name,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
      };

  factory VoiceCard.fromJson(Map<String, dynamic> json) => VoiceCard(
        id: json['id'] as String,
        workId: json['work_id'] as String? ?? json['workId'] as String,
        senderId: json['sender_id'] as String? ?? json['senderId'] as String,
        recipientId: json['recipient_id'] as String?,
        audioPath: json['audio_path'] as String?,
        textContent: json['text_content'] as String?,
        coverUrl: json['cover_url'] as String?,
        replyToId: json['reply_to_id'] as String?,
        direction: VoiceCardDirection.values.firstWhere(
          (e) => e.name == json['direction'],
          orElse: () => VoiceCardDirection.sent,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
      );

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
