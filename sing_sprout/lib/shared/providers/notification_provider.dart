import 'package:flutter/foundation.dart';
import '../repositories/voice_card_repository.dart';

/// 未读通知状态管理
class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  /// 刷新未读计数
  Future<void> refresh() async {
    final unread = await VoiceCardRepository().getUnread();
    final count = unread.length;
    if (count != _unreadCount) {
      _unreadCount = count;
      notifyListeners();
    }
  }

  /// 标记单张卡片为已读并更新计数
  Future<void> markRead(String cardId) async {
    await VoiceCardRepository().markAsRead(cardId);
    await refresh();
  }

  /// 初始化时加载未读计数
  Future<void> loadInitialCount() async {
    final unread = await VoiceCardRepository().getUnread();
    _unreadCount = unread.length;
    notifyListeners();
  }
}
