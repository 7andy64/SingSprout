import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/music_tree_data.dart';
import '../../shared/services/music_tree_service.dart';
import '../../shared/widgets/tree_visual.dart';

/// 我的音乐树 — 成长可视化系统
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
    final data = await MusicTreeService.calculate();
    if (!mounted) return;
    setState(() {
      _treeData = data;
      _loading = false;
    });
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
                // 树的可视化
                TreeVisual(
                  state: state,
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
                    state.description,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],

                const SizedBox(height: 32),

                // 创作统计
                _StatCard(
                  title: '创作统计',
                  children: [
                    _StatItem(
                      icon: '🎵',
                      label: '作品总数',
                      value: '${data?.totalWorks ?? 0}',
                    ),
                    _StatItem(
                      icon: '📅',
                      label: '累计使用',
                      value: '${data?.totalDays ?? 0} 天',
                    ),
                    _StatItem(
                      icon: '🔥',
                      label: '连续使用',
                      value: '${data?.streakDays ?? 0} 天',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 连接统计
                _StatCard(
                  title: '连接统计',
                  children: [
                    _StatItem(
                      icon: '📮',
                      label: '发送明信片',
                      value: '${data?.sharedCards ?? 0}',
                    ),
                    _StatItem(
                      icon: '💌',
                      label: '收到回信',
                      value: '${data?.receivedReplies ?? 0}',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 音乐根系
                _StatCard(
                  title: '音乐根系',
                  children: [
                    _ProgressBar(
                      label: '节奏感',
                      value: (data?.rhythmScore ?? 0) / 100,
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(
                      label: '音准',
                      value: (data?.pitchScore ?? 0) / 100,
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(
                      label: '听辨力',
                      value: (data?.listeningScore ?? 0) / 100,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0.0 - 1.0

  const _ProgressBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).round()}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
