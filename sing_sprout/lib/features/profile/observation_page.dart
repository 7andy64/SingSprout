import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';

/// 教师/家长观察窗 — 孩子的音乐创作数据看板
class ObservationPage extends StatelessWidget {
  const ObservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final works = appState.works;
        final cards = appState.cards;
        final profile = appState.userProfile;

        // 统计数据
        final totalWorks = works.length;
        final totalDuration = works.fold<Duration>(
          Duration.zero,
          (sum, w) => sum + w.duration,
        );
        final favCount = works.where((w) => w.isFavorite).length;
        final sentCards = cards
            .where((c) => c.direction == VoiceCardDirection.sent)
            .length;
        final receivedCards = cards
            .where((c) => c.direction == VoiceCardDirection.received)
            .length;

        // 活跃天数
        final activeDates = works.map((w) => _dateKey(w.createdAt)).toSet();

        // 最近作品
        final recentWorks = works.take(5).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('观察窗'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 孩子档案
              if (profile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Text(
                            profile.guardianAnimal.emoji,
                            style: const TextStyle(fontSize: 42),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.nickname,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.role.label} · ${profile.guardianAnimal.displayName} 陪伴中',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 核心指标
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '创作概览',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Row(
                children: [
                  _MetricTile(
                    icon: Icons.music_note_rounded,
                    value: '$totalWorks',
                    label: '作品',
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  _MetricTile(
                    icon: Icons.favorite,
                    value: '$favCount',
                    label: '收藏',
                    color: AppTheme.moodRed,
                  ),
                  const SizedBox(width: 8),
                  _MetricTile(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(totalDuration),
                    label: '创作时长',
                    color: const Color(0xFF7C4DFF),
                  ),
                  const SizedBox(width: 8),
                  _MetricTile(
                    icon: Icons.calendar_today,
                    value: '${activeDates.length}',
                    label: '活跃天数',
                    color: AppTheme.moodBlue,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 社交互动
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '社交互动',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.send, color: AppTheme.primaryGreen, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$sentCards',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const Text('发出明信片',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.mail, color: AppTheme.moodBlue, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$receivedCards',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.moodBlue,
                              ),
                            ),
                            const Text('收到回信',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 最近作品
              if (recentWorks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '最近作品',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                ...recentWorks.map((w) => _RecentWorkTile(work: w)),
              ],
            ],
          ),
        );
      },
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year}${date.month}${date.day}';

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }
}

/// 指标卡片
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最近作品条目
class _RecentWorkTile extends StatelessWidget {
  final MusicWork work;

  const _RecentWorkTile({required this.work});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(work.styleSeed.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${work.styleSeed.label} · ${_formatDuration(work.duration)} · ${work.createdAt.month}/${work.createdAt.day}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (work.isFavorite)
              const Icon(Icons.favorite, size: 16, color: AppTheme.moodRed),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
