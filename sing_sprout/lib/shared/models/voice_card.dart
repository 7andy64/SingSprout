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
      id: now.millisecondsSinceEpoch.toString(),
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
}

enum VoiceCardDirection { sent, received }
