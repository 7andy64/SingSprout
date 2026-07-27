import '../models/voice_card.dart';
import 'local_storage_service.dart';

/// 声音明信片仓库 — CRUD 持久化到 voice_cards.json
class VoiceCardRepository {
  static final VoiceCardRepository _instance = VoiceCardRepository._();
  factory VoiceCardRepository() => _instance;
  VoiceCardRepository._();

  static const _filename = 'voice_cards.json';
  final _storage = LocalStorageService();
  List<VoiceCard>? _cache;

  Future<List<VoiceCard>> getCards() async {
    if (_cache != null) return _cache!;

    final list = await _storage.readList(_filename);
    _cache = list.map((m) => VoiceCard.fromJson(m)).toList();
    return _cache!;
  }

  Future<void> addCard(VoiceCard card) async {
    final cards = await getCards();
    cards.insert(0, card); // 最新的在前
    await _persist(cards);
  }

  Future<void> markAsRead(String cardId) async {
    final cards = await getCards();
    final idx = cards.indexWhere((c) => c.id == cardId);
    if (idx == -1) return;

    final old = cards[idx];
    cards[idx] = VoiceCard(
      id: old.id,
      workId: old.workId,
      senderId: old.senderId,
      recipientId: old.recipientId,
      audioPath: old.audioPath,
      textContent: old.textContent,
      coverUrl: old.coverUrl,
      replyToId: old.replyToId,
      direction: old.direction,
      createdAt: old.createdAt,
      readAt: DateTime.now(),
    );
    await _persist(cards);
  }

  Future<int> getUnreadCount() async {
    final cards = await getCards();
    return cards.where((c) => c.isUnread).length;
  }

  /// 获取未读回信列表
  Future<List<VoiceCard>> getUnreadReplies() async {
    final cards = await getCards();
    return cards.where((c) => c.isUnread).toList();
  }

  void clearCache() {
    _cache = null;
  }

  Future<void> _persist(List<VoiceCard> cards) async {
    _cache = cards;
    await _storage.writeList(
      _filename,
      cards.map((c) => c.toJson()).toList(),
    );
  }
}
