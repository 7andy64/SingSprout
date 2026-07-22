import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/sound_sample.dart';
import '../../shared/providers/app_state.dart';

/// 我的声音库 — 展示田野声音实验室采集的声音样本
class SoundsPage extends StatelessWidget {
  const SoundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final sounds = appState.sounds;

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的声音库'),
            centerTitle: true,
          ),
          body: sounds.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: sounds.length,
                  itemBuilder: (_, i) => _SoundCard(
                    sound: sounds[i],
                    onDelete: () => _confirmDelete(context, sounds[i]),
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
          const Text('🎤', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '还没有采集声音',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去田野声音实验室采集你的第一个声音吧',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SoundSample sound) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除声音'),
        content: Text('确定要删除「${sound.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteSound(sound.id);
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

/// 声音样本卡片
class _SoundCard extends StatelessWidget {
  final SoundSample sound;
  final VoidCallback onDelete;

  const _SoundCard({required this.sound, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 左侧类型图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _typeColor(sound.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _typeEmoji(sound.type),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sound.name,
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
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _typeColor(sound.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sound.type.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: _typeColor(sound.type),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (sound.bpm != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'BPM ${sound.bpm!.round()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (sound.timbreFeature != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            sound.timbreFeature!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sound.pitchSequence != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '音高: ${sound.pitchSequence}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (sound.recommendedUse != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '推荐: ${sound.recommendedUse}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(sound.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 删除按钮
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(SoundType type) {
    switch (type) {
      case SoundType.humanVoice:
        return const Color(0xFFFF6B6B);
      case SoundType.animal:
        return const Color(0xFFFFB347);
      case SoundType.nature:
        return AppTheme.primaryGreen;
      case SoundType.mechanical:
        return const Color(0xFF7C4DFF);
      case SoundType.unknown:
        return AppTheme.textSecondary;
    }
  }

  String _typeEmoji(SoundType type) {
    switch (type) {
      case SoundType.humanVoice:
        return '🗣️';
      case SoundType.animal:
        return '🐾';
      case SoundType.nature:
        return '🌿';
      case SoundType.mechanical:
        return '⚙️';
      case SoundType.unknown:
        return '❓';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
