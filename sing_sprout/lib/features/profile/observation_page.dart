import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/utils/formatters.dart';

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
        final sentCards =
            cards.where((c) => c.direction == VoiceCardDirection.sent).length;
        final receivedCards =
            cards.where((c) => c.direction == VoiceCardDirection.received).length;

        // 活跃天数
        final activeDates =
            works.map((w) => _dateKey(w.createdAt)).toSet();

        // 最近7天趋势
        final trendData = _build7DayTrend(works);

        // 风格探索
        final styleUsage = _buildStyleUsage(works);

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
                _buildProfileCard(profile),

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
                    value: Formatters.formatDuration(totalDuration),
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

              // 7天趋势图
              if (trendData.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '近7天创作趋势',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                _TrendChart(data: trendData),
                const SizedBox(height: 20),
              ],

              // 风格探索
              if (styleUsage.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '风格探索',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                _StyleExplorer(usage: styleUsage),
                const SizedBox(height: 20),
              ],

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
                            const Icon(Icons.send,
                                color: AppTheme.primaryGreen, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$sentCards',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const Text(
                              '发出明信片',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
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
                            const Icon(Icons.mail,
                                color: AppTheme.moodBlue, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$receivedCards',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.moodBlue,
                              ),
                            ),
                            const Text(
                              '收到回信',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
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

  // ── 档案卡片 ──

  Widget _buildProfileCard(UserProfile profile) {
    return Padding(
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
    );
  }

  // ── 7天趋势数据 ──

  static List<_DayCount> _build7DayTrend(List<MusicWork> works) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <_DayCount>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final count = works.where((w) {
        final wd = DateTime(w.createdAt.year, w.createdAt.month, w.createdAt.day);
        return wd == day;
      }).length;
      result.add(_DayCount(
        date: day,
        count: count,
        label: i == 0 ? '今天' : '${day.month}/${day.day}',
      ));
    }

    return result;
  }

  // ── 风格使用统计 ──

  static List<_StyleUsage> _buildStyleUsage(List<MusicWork> works) {
    final map = <StyleSeed, int>{};
    for (final w in works) {
      map[w.styleSeed] = (map[w.styleSeed] ?? 0) + 1;
    }
    return map.entries
        .map((e) => _StyleUsage(style: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  static String _dateKey(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════
//  数据类
// ═══════════════════════════════════════════════

class _DayCount {
  final DateTime date;
  final int count;
  final String label;
  const _DayCount({required this.date, required this.count, required this.label});
}

class _StyleUsage {
  final StyleSeed style;
  final int count;
  const _StyleUsage({required this.style, required this.count});
}

// ═══════════════════════════════════════════════
//  7天趋势柱状图
// ═══════════════════════════════════════════════

class _TrendChart extends StatelessWidget {
  final List<_DayCount> data;
  const _TrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final effectiveMax = maxCount > 0 ? maxCount : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            // 柱状图行
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((d) {
                  final fraction = d.count / effectiveMax;
                  final barHeight = fraction * 80;
                  final isToday = d.label == '今天';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 数值标签
                          if (d.count > 0)
                            Text(
                              '${d.count}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 4),
                          // 柱子
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            height: barHeight < 4 ? 4 : barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [
                                        AppTheme.primaryGreen,
                                        AppTheme.primaryGreen.withValues(alpha: 0.6),
                                      ]
                                    : [
                                        AppTheme.primaryGreen.withValues(alpha: 0.5),
                                        AppTheme.primaryGreen.withValues(alpha: 0.2),
                                      ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 日期标签
                          Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isToday ? FontWeight.w600 : FontWeight.w400,
                              color: isToday
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // 汇总行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trending_up, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '本周共创作 ${data.fold<int>(0, (s, d) => s + d.count)} 首',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  风格探索组件
// ═══════════════════════════════════════════════

class _StyleExplorer extends StatelessWidget {
  final List<_StyleUsage> usage;
  const _StyleExplorer({required this.usage});

  @override
  Widget build(BuildContext context) {
    final totalWorks =
        usage.fold<int>(0, (s, u) => s + u.count);
    final exploredCount = usage.length;
    final totalStyles = StyleSeed.values.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 探索进度头
            Row(
              children: [
                const Icon(Icons.explore, size: 20, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 6),
                Text(
                  '已探索 $exploredCount / $totalStyles 种风格',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(exploredCount / totalStyles * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 探索进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: exploredCount / totalStyles,
                minHeight: 6,
                backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
              ),
            ),
            const SizedBox(height: 16),

            // 各风格详情
            ...usage.map((u) => _StyleRow(usage: u, total: totalWorks)),
          ],
        ),
      ),
    );
  }
}

class _StyleRow extends StatelessWidget {
  final _StyleUsage usage;
  final int total;
  const _StyleRow({required this.usage, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? usage.count / total : 0.0;
    final percent = (fraction * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                usage.style.icon,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usage.style.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${usage.count}首',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen.withValues(alpha: 0.5 + fraction * 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  指标卡片
// ═══════════════════════════════════════════════

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

// ═══════════════════════════════════════════════
//  最近作品条目
// ═══════════════════════════════════════════════

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
                    '${work.styleSeed.label} · ${Formatters.formatDurationMinSec(work.duration)} · ${work.createdAt.month}/${work.createdAt.day}',
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
}
