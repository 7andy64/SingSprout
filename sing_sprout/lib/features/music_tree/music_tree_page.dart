import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/music_tree_data.dart';
import '../../shared/services/music_tree_service.dart';
import '../../shared/widgets/tree_visual.dart';

/// 我的音乐树 — 极简版成长可视化系统
///
/// 按优化方案，MVP 聚焦「作品数量 + 连续活跃」两维度，
/// 补充心情维度连接形成双维成长树。
/// 连接统计、音乐根系等指标在 P2 阶段恢复。
class MusicTreePage extends StatefulWidget {
  const MusicTreePage({super.key});

  @override
  State<MusicTreePage> createState() => _MusicTreePageState();
}

class _MusicTreePageState extends State<MusicTreePage> {
  MusicTreeData? _treeData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await MusicTreeService.calculate();
      if (!mounted) return;
      setState(() {
        _treeData = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _treeData;
    final state = data?.treeState ?? TreeState.sprouting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的音乐树'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TreeVisual(
                  state: state,
                  growthEnergy: data?.growthEnergy ?? 0,
                  moodColorHint: data != null && data.moodRecordCount > 0
                      ? _moodSummaryColor(data)
                      : null,
                  height: 220,
                ),

                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Text(
                    state.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stateMessage(data),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],

                const SizedBox(height: 32),

                _StatCard(
                  title: '创作与活跃',
                  children: [
                    _StatItem(
                      icon: '🎵',
                      label: '作品总数',
                      value: '${data?.totalWorks ?? 0} 首',
                      subtitle: '每一次哼唱都在成长',
                    ),
                    const Divider(height: 20),
                    _StatItem(
                      icon: '🔥',
                      label: '连续使用',
                      value: '${data?.streakDays ?? 0} 天',
                      subtitle: data != null && data.streakDays >= 7
                          ? '坚持很棒！'
                          : '每一天都是进步',
                    ),
                  ],
                ),

                if (data != null && data.moodRecordCount > 0) ...[
                  const SizedBox(height: 16),
                  _StatCard(
                    title: '心情印记',
                    children: [
                      _StatItem(
                        icon: '💬',
                        label: '心情记录',
                        value: '${data.moodRecordCount} 次',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MoodDayChip(
                            label: '开心日子',
                            count: data.positiveMoodDays,
                            color: AppTheme.moodGreen,
                          ),
                          const SizedBox(width: 12),
                          _MoodDayChip(
                            label: '想念日子',
                            count: data.negativeMoodDays,
                            color: AppTheme.moodBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                if (data != null) ...[
                  const SizedBox(height: 16),
                  _StatCard(
                    title: '成长能量',
                    children: [
                      _GrowthEnergyBar(value: data.growthEnergy / 100),
                      const SizedBox(height: 8),
                      Text(
                        _energyTip(data.growthEnergy),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stateMessage(MusicTreeData? data) {
    if (data == null) return '';
    if (data.moodRecordCount == 0 && data.totalWorks == 0) {
      return '去哼唱花园录一首歌吧';
    }
    if (data.moodRecordCount == 0) {
      return '录完歌后，也去心情收音机说说感受吧';
    }
    if (data.totalWorks == 0 && data.moodRecordCount > 0) {
      return '你的心情树在等第一首歌';
    }
    return data.treeState.description;
  }

  String _energyTip(double energy) {
    if (energy < 20) return '种子正在吸收养分…';
    if (energy < 40) return '嫩芽破土，继续加油！';
    if (energy < 60) return '小树苗正在茁壮成长';
    if (energy < 80) return '枝叶日渐茂密啦';
    return '你的音乐树生机勃勃！';
  }

  Color _moodSummaryColor(MusicTreeData data) {
    final total = data.positiveMoodDays + data.negativeMoodDays;
    if (total == 0) return AppTheme.primaryGreen;
    final positiveRatio = data.positiveMoodDays / total;
    if (positiveRatio > 0.7) return AppTheme.moodGreen;
    if (positiveRatio < 0.3) return AppTheme.moodBlue;
    return AppTheme.primaryWarm;
  }
}

// ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String? subtitle;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _MoodDayChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MoodDayChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthEnergyBar extends StatelessWidget {
  final double value; // 0.0 - 1.0

  const _GrowthEnergyBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppTheme.primarySoil,
      AppTheme.primaryGreen,
      value,
    )!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(value * 100).round()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
