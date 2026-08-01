import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_tree_data.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/music_tree_service.dart';
import '../../shared/services/role_permissions.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/role_gate.dart';
import '../../shared/widgets/tree_visual.dart';
import 'widgets/garden_widgets.dart';

/// Garden page — mascot greeting → mini music tree → record entry → stats.
class HummingGardenPage extends StatefulWidget {
  final VoidCallback? onFloatingRecord;
  const HummingGardenPage({super.key, this.onFloatingRecord});

  @override
  State<HummingGardenPage> createState() => _HummingGardenPageState();
}

class _HummingGardenPageState extends State<HummingGardenPage>
    with TickerProviderStateMixin {
  MusicTreeData? _treeData;
  bool _loading = true;

  late final AnimationController _animalBreatheController;
  late final AnimationController _treeSwayController;

  @override
  void initState() {
    super.initState();
    _loadTreeData();
    _animalBreatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
      setState(() { _treeData = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _startCreativeFlow() {
    context.push(AppRoutes.creativeFlow).then((_) => _loadTreeData());
  }

  @override
  Widget build(BuildContext context) {
    final state = _treeData?.treeState ?? TreeState.sprouting;
    final energy = _treeData?.growthEnergy ?? 0;
    final hasMoodData = _treeData != null && _treeData!.moodRecordCount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('🌱 花园'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTreeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              const SizedBox(height: 16),
              // ── Mascot greeting ──
              AnimatedBuilder(
                animation: _animalBreatheController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: 1.0 + _animalBreatheController.value * 0.03,
                    child: Consumer<AppState>(
                      builder: (_, app, __) => AnimalAvatar(
                          animal: app.userProfile?.guardianAnimal ??
                              GuardianAnimal.panda,
                          size: 72,
                          speechBubble:
                              '嘿！今天想哼点什么？\n试试用音乐种一棵树吧～'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // ── Mini music tree ──
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
                        moodColorHint: hasMoodData
                            ? _moodSummaryColor(_treeData!)
                            : null,
                        height: 160,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(state.label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(_stateMessage(),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: MiniEnergyBar(value: energy / 100),
                ),
              ],
              const SizedBox(height: 16),
              // ── Record button ──
              Consumer<AppState>(
                builder: (context, app, _) {
                  final role = app.userProfile?.role ?? UserRole.student;
                  return RoleGate(
                    feature: Feature.createMusic,
                    role: role,
                    fallback: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '当前身份不支持创作功能',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _startCreativeFlow,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primaryGreen.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text('🎤',
                                style: TextStyle(fontSize: 36)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('点击开始创作',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // ── Quick actions ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QuickActionChip(
                      icon: '💜',
                      label: '记录心情',
                      onTap: () =>
                          context.push(AppRoutes.moodRadio),
                    ),
                    const SizedBox(width: 12),
                    QuickActionChip(
                      icon: '📊',
                      label: '详细统计',
                      onTap: () => _showDailyStats(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Recent works ──
              const RecentWorksSection(),
              const SizedBox(height: 20),
              // ── Creation stats ──
              if (_treeData != null) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: StatCard(
                    title: '创作与活跃',
                    children: [
                      StatItem(
                        icon: '🎵',
                        label: '作品总数',
                        value: '${_treeData!.totalWorks} 首',
                        subtitle: '每一次哼唱都在成长',
                      ),
                      const Divider(height: 20),
                      StatItem(
                        icon: '🔥',
                        label: '连续使用',
                        value: '${_treeData!.streakDays} 天',
                        subtitle: _treeData!.streakDays >= 7
                            ? '坚持很棒！'
                            : '每一天都是进步',
                      ),
                    ],
                  ),
                ),
                if (hasMoodData) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    child: StatCard(
                      title: '心情印记',
                      children: [
                        StatItem(
                          icon: '💬',
                          label: '心情记录',
                          value:
                              '${_treeData!.moodRecordCount} 次',
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          MoodDayChip(
                            label: '开心日子',
                            count: _treeData!.positiveMoodDays,
                            color: AppTheme.moodGreen,
                          ),
                          const SizedBox(width: 12),
                          MoodDayChip(
                            label: '想念日子',
                            count: _treeData!.negativeMoodDays,
                            color: AppTheme.moodBlue,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 40),
            ]),
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

  void _showDailyStats(BuildContext context) {
    final appState = context.read<AppState>();
    final works = appState.works;
    final Map<String, int> dailyCount = {};
    for (final w in works) {
      final day =
          '${w.createdAt.year}-${w.createdAt.month.toString().padLeft(2, '0')}-${w.createdAt.day.toString().padLeft(2, '0')}';
      dailyCount[day] = (dailyCount[day] ?? 0) + 1;
    }
    final sortedDays = dailyCount.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 每日创作统计',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('共 ${works.length} 首作品',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              if (sortedDays.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: Text('还没有作品，开始哼唱吧 🎤',
                          style: TextStyle(
                              color: AppTheme.textSecondary))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedDays.length,
                    itemBuilder: (_, i) {
                      final day = sortedDays[i];
                      final count = dailyCount[day]!;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Text(day,
                              style: const TextStyle(fontSize: 14)),
                          const Spacer(),
                          Text('$count 首',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen)),
                        ]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
