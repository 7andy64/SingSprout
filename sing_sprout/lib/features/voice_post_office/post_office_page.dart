import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';

/// 声音邮局 — 亲子音乐明信片收发
class PostOfficePage extends StatelessWidget {
  const PostOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('声音邮局'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 写新明信片入口
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.composeCard),
                  icon: const Text('✍️', style: TextStyle(fontSize: 22)),
                  label: const Text('写一张音乐明信片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: AppTheme.textPrimary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tab 切换：发件箱 / 收件箱
            const DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppTheme.primaryGreen,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryGreen,
                      tabs: [
                        Tab(text: '发件箱'),
                        Tab(text: '收件箱'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _CardList(direction: VoiceCardDirection.sent),
                          _CardList(direction: VoiceCardDirection.received),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 明信片列表
class _CardList extends StatelessWidget {
  final VoiceCardDirection direction;
  const _CardList({required this.direction});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cards = appState.cards
        .where((c) => c.direction == direction)
        .toList();

    if (cards.isEmpty) {
      return _EmptyState(
        icon: direction == VoiceCardDirection.sent
            ? '📤'
            : '📬',
        message: direction == VoiceCardDirection.sent
            ? '还没有发送过明信片\n创作一首歌然后发给爸妈'
            : '还没有收到回信\n试试给爸妈发第一张明信片吧',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _CardItem(card: cards[index]);
      },
    );
  }
}

/// 单张明信片
class _CardItem extends StatelessWidget {
  final VoiceCard card;
  const _CardItem({required this.card});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final work = appState.works
        .where((w) => w.id == card.workId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
          child: Text(
            work?.styleSeed.icon ?? '🎵',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          work?.title ?? '未知作品',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.textContent != null && card.textContent!.isNotEmpty)
              Text(
                card.textContent!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            Text(
              _formatDate(card.createdAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Text('📤', style: TextStyle(fontSize: 20)),
          onPressed: () => _shareCard(context),
          tooltip: '再次分享',
        ),
        onTap: () => _shareCard(context),
      ),
    );
  }

  Future<void> _shareCard(BuildContext context) async {
    if (card.coverUrl != null && card.coverUrl!.isNotEmpty) {
      try {
        await Share.shareXFiles(
          [XFile(card.coverUrl!)],
          text: '🎵 ${card.textContent ?? "分享一首音乐给你"}',
        );
      } catch (_) {
        // 文件不存在时静默
      }
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Text(icon, style: TextStyle(fontSize: 56, color: AppTheme.textSecondary.withValues(alpha: 0.3))),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
