import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/social_share_service.dart';

/// 声音邮局 — 发件箱
class PostOfficePage extends StatelessWidget {
  const PostOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cards = appState.cards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('声音邮局'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.composeCard),
                  icon: const Text('✍️', style: TextStyle(fontSize: 22)),
                  label: const Text('分享一首歌'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: AppTheme.textPrimary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (cards.isEmpty)
              _EmptyState()
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    return _CardItem(card: cards[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            Row(
              children: [
                if (card.greetingAudioPath != null) ...[
                  const Text('🎙️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                ],
                Text(
                  _formatDate(card.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
          onSelected: (value) {
            if (value == 'share') {
              _reshareCard(context);
            } else if (value == 'delete') {
              _confirmDelete(context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'share', child: Text('📤 分享')),
            const PopupMenuItem(value: 'delete', child: Text('🗑️ 删除')),
          ],
        ),
        onTap: () => _reshareCard(context),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分享'),
        content: const Text('确定要删除这条分享记录吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteVoiceCard(card.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _reshareCard(BuildContext context) {
    final appState = context.read<AppState>();
    final work = appState.works.where((w) => w.id == card.workId).firstOrNull;
    final audioPath = card.audioPath ?? work?.audioPath;

    if (audioPath == null || audioPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音频文件不存在')),
      );
      return;
    }

    SocialShareService.showShareOptions(
      context,
      audioPath: audioPath,
      title: work?.title ?? '音乐分享',
      message: card.textContent ?? '',
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Text('🎵', style: TextStyle(fontSize: 56, color: AppTheme.textSecondary)),
          SizedBox(height: 16),
          Text(
            '还没有分享过音乐\n创作一首歌然后发给爸妈',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
