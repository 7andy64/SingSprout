import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/record_button.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/tree_visual.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/music_tree_data.dart';
import '../../shared/services/music_tree_service.dart';

/// 🌱 花园 — 合并哼唱花园 + 音乐树
///
/// 首页：守护动物引导 → 迷你音乐树（动态生长）→ 录音入口 → 创作统计。
/// P0/P1 优化：树预览前置、数据驱动生长、心情入口内嵌。
class HummingGardenPage extends StatefulWidget {
  final VoidCallback? onFloatingRecord; // 外部传入的浮动录音回调

  const HummingGardenPage({super.key, this.onFloatingRecord});

  @override
  State<HummingGardenPage> createState() => _HummingGardenPageState();
}

class _HummingGardenPageState extends State<HummingGardenPage>
    with TickerProviderStateMixin {
  MusicTreeData? _treeData;
  bool _loading = true;

  late AnimationController _animalBreatheController;
  late AnimationController _treeSwayController;

  @override
  void initState() {
    super.initState();
    _loadTreeData();

    // 动物呼吸动画
    _animalBreatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 树叶微摆
    _treeSwayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animalBreatheController.dispose();
    _treeSwayController.dispose();
    super.dispose();
  }

  Future<void> _loadTreeData() async {
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

  void _startCreativeFlow() {
    context.push(AppRoutes.creativeFlow).then((_) {
      // 返回后刷新树数据（可能新增了作品）
      _loadTreeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _treeData?.treeState ?? TreeState.sprouting;
    final energy = _treeData?.growthEnergy ?? 0;
    final hasMoodData = _treeData != null && _treeData!.moodRecordCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌱 花园'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTreeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ── 守护动物问候（呼吸动画） ──
                AnimatedBuilder(
                  animation: _animalBreatheController,
                  builder: (context, _) {
                    final scale = 1.0 + _animalBreatheController.value * 0.03;
                    return Transform.scale(
                      scale: scale,
                      child: const AnimalAvatar(
                        animal: GuardianAnimal.panda,
                        size: 72,
                        speechBubble: '嘿！今天想哼点什么？\n试试用音乐种一棵树吧～',
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── 迷你音乐树 ──
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  AnimatedBuilder(
                    animation: _treeSwayController,
                    builder: (context, _) {
                      return SizedBox(
                        height: 160,
                        child: TreeVisual(
                          state: state,
                          growthEnergy: energy,
                          moodColorHint: hasMoodData ? _moodSummaryColor(_treeData!) : null,
                          height: 160,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  Text(
                    _stateMessage(),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),

                  // 成长能量条
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: _MiniEnergyBar(value: energy / 100),
                  ),
                ],

                const SizedBox(height: 16),

                // ── 录音按钮 ──
                RecordButton(
                  onRecordingStart: () {},
                  onRecordingStop: _startCreativeFlow,
                  size: 80,
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击开始创作',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),

                const SizedBox(height: 20),

                // ── 快捷入口行 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _QuickActionChip(
                        icon: '💜',
                        label: '记录心情',
                        onTap: () => context.push(AppRoutes.moodRadio),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionChip(
                        icon: '📊',
                        label: '详细统计',
                        onTap: () {}, // 滚动到下方统计区
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 最近作品 ──
                _RecentWorksSection(),

                const SizedBox(height: 20),

                // ── 创作统计卡片（来自原音乐树页） ──
                if (_treeData != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _StatCard(
                      title: '创作与活跃',
                      children: [
                        _StatItem(
                          icon: '🎵',
                          label: '作品总数',
                          value: '${_treeData!.totalWorks} 首',
                          subtitle: '每一次哼唱都在成长',
                        ),
                        const Divider(height: 20),
                        _StatItem(
                          icon: '🔥',
                          label: '连续使用',
                          value: '${_treeData!.streakDays} 天',
                          subtitle: _treeData!.streakDays >= 7 ? '坚持很棒！' : '每一天都是进步',
                        ),
                      ],
                    ),
                  ),

                  if (hasMoodData) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatCard(
                        title: '心情印记',
                        children: [
                          _StatItem(
                            icon: '💬',
                            label: '心情记录',
                            value: '${_treeData!.moodRecordCount} 次',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _MoodDayChip(
                                label: '开心日子',
                                count: _treeData!.positiveMoodDays,
                                color: AppTheme.moodGreen,
                              ),
                              const SizedBox(width: 12),
                              _MoodDayChip(
                                label: '想念日子',
                                count: _treeData!.negativeMoodDays,
                                color: AppTheme.moodBlue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stateMessage() {
    final data = _treeData;
    if (data == null) return '';
    if (data.moodRecordCount == 0 && data.totalWorks == 0) {
      return '去哼唱花园录一首歌吧';
    }
    final energy = data.growthEnergy;
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

// ═══════════════════════════════════════════════════════════
// 快捷入口芯片
// ═══════════════════════════════════════════════════════════

class _QuickActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen.withOpacity(0.06),
              AppTheme.primaryWarm.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 迷你能量条
// ═══════════════════════════════════════════════════════════

class _MiniEnergyBar extends StatelessWidget {
  final double value;

  const _MiniEnergyBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppTheme.primarySoil, AppTheme.primaryGreen, value)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 最近作品（保留原设计）
// ═══════════════════════════════════════════════════════════

class _RecentWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近作品',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryGreen.withOpacity(0.08 + index * 0.03),
                        AppTheme.primaryWarm.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: AppTheme.primaryGreen, size: 32),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 统计卡片组件（从 music_tree_page 迁移）
// ═══════════════════════════════════════════════════════════

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.bgWarm.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15),
        ),
      ],
    );
  }
}

class _MoodDayChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MoodDayChip({required this.label, required this.count, required this.color});

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
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
