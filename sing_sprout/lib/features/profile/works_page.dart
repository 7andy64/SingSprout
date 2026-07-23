import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/utils/formatters.dart';

/// 我的作品集 — 展示所有创作的音乐作品
class WorksPage extends StatelessWidget {
  const WorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final works = appState.works;

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的作品集'),
            centerTitle: true,
          ),
          body: works.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: works.length,
                  itemBuilder: (_, i) => _WorkCard(
                    work: works[i],
                    onFavorite: () =>
                        context.read<AppState>().toggleFavorite(works[i].id),
                    onDelete: () => _confirmDelete(context, works[i]),
                    onTap: () {
                      context.push('${AppRoutes.workDetail}?id=${works[i].id}');
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎵', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '还没有作品',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去哼唱花园录制你的第一首歌吧',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MusicWork work) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除作品'),
        content: Text('确定要删除「${work.title}」吗？\n删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteWork(work.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 作品卡片
class _WorkCard extends StatelessWidget {
  final MusicWork work;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _WorkCard({
    required this.work,
    required this.onFavorite,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = Formatters.formatDurationMinSec(work.duration);
    final dateStr = Formatters.formatDateShort(work.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧封面
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    work.styleSeed.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // 风格标签
                        Text(
                          '${work.styleSeed.icon} ${work.styleSeed.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (work.moodSticker != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            work.moodSticker!.emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                        const Spacer(),
                        // 时长
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // 右侧操作
              Column(
                children: [
                  // 收藏按钮
                  IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      work.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: work.isFavorite
                          ? AppTheme.moodRed
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 删除按钮
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
