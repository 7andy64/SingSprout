import '../models/voice_card.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

/// 离线发件箱队列 — 断网时缓存明信片，联网后自动发送
class OutboxQueueService {
  static final OutboxQueueService _instance = OutboxQueueService._();
  factory OutboxQueueService() => _instance;
  OutboxQueueService._();

  static const _filename = 'pending_outbox.json';
  final _storage = LocalStorageService();

  /// 加入发送队列
  Future<void> enqueue(VoiceCard card) async {
    final list = await _storage.readList(_filename);
    list.add(card.toJson());
    await _storage.writeList(_filename, list);
  }

  /// 处理队列中所有待发送的明信片
  Future<void> processQueue() async {
    final list = await _storage.readList(_filename);
    if (list.isEmpty) return;

    final api = ApiService();
    final remaining = <Map<String, dynamic>>[];

    for (final item in list) {
      try {
        final card = VoiceCard.fromJson(item);
        await api.generateShareLink(
          cardId: card.id,
          audioUrl: card.audioPath ?? '',
          coverUrl: card.coverUrl,
          textContent: card.textContent,
        );
        // 发送成功，从队列移除（不加入 remaining）
      } catch (_) {
        // 发送失败，保留在队列
        remaining.add(item);
      }
    }

    await _storage.writeList(_filename, remaining);
  }

  /// 待发送数量
  Future<int> get pendingCount async {
    final list = await _storage.readList(_filename);
    return list.length;
  }
}
