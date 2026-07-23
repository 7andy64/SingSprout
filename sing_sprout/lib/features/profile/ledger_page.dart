import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';

/// 家庭音乐账本 — 声音明信片收发记录聚合视图
class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭音乐账本'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: '发出的'),
            Tab(text: '收到的'),
          ],
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _CardList(
                cards: appState.cards
                    .where((c) => c.direction == VoiceCardDirection.sent)
                    .toList(),
                emptyLabel: '还没有发出明信片',
                emptyHint: '完成一首作品后可以分享给家人',
                onMarkRead: (id) => context.read<AppState>().markCardAsRead(id),
              ),
              _CardList(
                cards: appState.cards
                    .where((c) => c.direction == VoiceCardDirection.received)
                    .toList(),
                emptyLabel: '还没有收到回信',
                emptyHint: '家人回复你的明信片后会出现在这里',
                onMarkRead: (id) => context.read<AppState>().markCardAsRead(id),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 明信片列表（可复用）
class _CardList extends StatelessWidget {
  final List<VoiceCard> cards;
  final String emptyLabel;
  final String emptyHint;
  final Future<void> Function(String) onMarkRead;

  const _CardList({
    required this.cards,
    required this.emptyLabel,
    required this.emptyHint,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✉️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptyHint,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: cards.length,
      itemBuilder: (_, i) => _CardItem(
        card: cards[i],
        onTap: () async => onMarkRead(cards[i].id),
      ),
    );
  }
}

/// 单张明信片
class _CardItem extends StatelessWidget {
  final VoiceCard card;
  final VoidCallback onTap;

  const _CardItem({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = card.readAt == null;
    final isReceived = card.direction == VoiceCardDirection.received;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 方向图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isReceived ? AppTheme.moodBlue : AppTheme.primaryGreen)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReceived ? Icons.mail : Icons.send,
                  size: 22,
                  color: isReceived
                      ? AppTheme.moodBlue
                      : AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 14),

              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.textContent ?? '(无内容)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isUnread ? FontWeight.w600 : FontWeight.w400,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.moodRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (card.audioPath != null) ...[
                          const Icon(Icons.mic, size: 13,
                              color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          const Text('含语音',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          _formatDate(card.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (isReceived && card.readAt != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.done_all, size: 14,
                              color: AppTheme.primaryGreen),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
