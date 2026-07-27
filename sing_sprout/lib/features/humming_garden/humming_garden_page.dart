import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_state.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/music_tree_data.dart';
import '../../shared/services/music_tree_service.dart';
import '../../shared/widgets/record_button.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/tree_visual.dart';

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

                // ── 进入创作按钮 ──
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
                          color: AppTheme.primaryGreen.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 36),
                  ),
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
                        onTap: () => _showDailyStats(context),
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

  void _showDailyStats(BuildContext context) {
    final appState = context.read<AppState>();
    final works = appState.works;
    final Map<String, int> dailyCount = {};
    for (final w in works) {
      final day = '${w.createdAt.year}-${w.createdAt.month.toString().padLeft(2, '0')}-${w.createdAt.day.toString().padLeft(2, '0')}';
      dailyCount[day] = (dailyCount[day] ?? 0) + 1;
    }
    final sortedDays = dailyCount.keys.toList()..sort((a, b) => b.compareTo(a));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 每日创作统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('共 ${works.length} 首作品', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              if (sortedDays.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('还没有作品，开始哼唱吧 🎤', style: TextStyle(color: AppTheme.textSecondary))))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedDays.length,
                    itemBuilder: (_, i) {
                      final day = sortedDays[i];
                      final count = dailyCount[day]!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Text(day, style: const TextStyle(fontSize: 14)),
                          const Spacer(),
                          Text('$count 首', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
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
              AppTheme.primaryGreen.withValues(alpha: 0.06),
              AppTheme.primaryWarm.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.06),
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
        backgroundColor: color.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 最近作品（保留原设计）
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// 最近作品 — 心情小树卡片（Phase 1-4 完整重写）
// ═══════════════════════════════════════════════════════════

class _RecentWorksSection extends StatefulWidget {
  @override
  State<_RecentWorksSection> createState() => _RecentWorksSectionState();
}

class _RecentWorksSectionState extends State<_RecentWorksSection> {
  final _recentScroll = ScrollController();
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _appeared = true);
    });
  }

  @override
  void dispose() {
    _recentScroll.dispose();
    super.dispose();
  }

  /// 心情 → 卡片底色
  static Color _moodBgColor(MoodColor? mood) {
    switch (mood) {
      case MoodColor.red: return const Color(0xFFFFF0E8);
      case MoodColor.yellow: return const Color(0xFFFFF8E0);
      case MoodColor.green: return const Color(0xFFE8F5E9);
      case MoodColor.blue: return const Color(0xFFE8F0FD);
      case MoodColor.purple: return const Color(0xFFF3E5F5);
      case MoodColor.grey: return const Color(0xFFF5F5F5);
      case null: return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final works = context.watch<AppState>().works;
    final recent = works.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('最近作品',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              if (works.isNotEmpty)
                TextButton(
                  onPressed: () => context.push(AppRoutes.works),
                  child: const Text('查看全部'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            _EmptyWorksPlaceholder()
          else
            SizedBox(
              height: 158,
              child: ListView.separated(
                controller: _recentScroll,
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final delayed = _appeared;
                  return delayed
                      ? _WorkTreeCard(work: recent[index], delayMs: index * 80)
                      : const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 空状态：嫩芽 + 引导文案 + 立即创作按钮
class _EmptyWorksPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('还没有作品', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('去创作页录制你的第一首歌吧', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.creativeFlow),
            icon: const Text('🌿', style: TextStyle(fontSize: 16)),
            label: const Text('立即创作'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 心情小树卡片（支持单击试听 / 长按菜单）
class _WorkTreeCard extends StatefulWidget {
  final MusicWork work;
  final int delayMs;

  const _WorkTreeCard({required this.work, this.delayMs = 0});

  @override
  State<_WorkTreeCard> createState() => _WorkTreeCardState();
}

class _WorkTreeCardState extends State<_WorkTreeCard> with SingleTickerProviderStateMixin {
  late AnimationController _fadeSlideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _fadeSlideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _fadeSlideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeSlideCtrl.dispose();
    super.dispose();
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PreviewSheet(work: widget.work),
    );
  }

  void _showContextMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WorkMenu(work: widget.work),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _RecentWorksSectionState._moodBgColor(widget.work.moodSticker);
    final isToday = widget.work.createdAt.year == DateTime.now().year &&
        widget.work.createdAt.month == DateTime.now().month &&
        widget.work.createdAt.day == DateTime.now().day;
    final timeStr = '${widget.work.createdAt.hour.toString().padLeft(2, '0')}:${widget.work.createdAt.minute.toString().padLeft(2, '0')}';
    final moodLabel = widget.work.moodSticker?.label ?? '未标记';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: _showPreview,
          onLongPressStart: (_) => setState(() => _isPressed = true),
          onLongPressEnd: (_) { setState(() => _isPressed = false); _showContextMenu(); },
          onLongPressCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgColor, bgColor.withValues(alpha: 0.4)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isPressed ? AppTheme.primaryGreen : Colors.black).withValues(alpha: _isPressed ? 0.15 : 0.06),
                    blurRadius: _isPressed ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 心情小树插画
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: CustomPaint(
                          size: const Size(72, 72),
                          painter: _MoodTreePainter(widget.work.moodSticker),
                        ),
                      ),
                    ),
                  ),
                  // 底部信息
                  Positioned(
                    bottom: 12, left: 10, right: 10,
                    child: Column(
                      children: [
                        Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                        const SizedBox(height: 2),
                        Text(moodLabel, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                      ],
                    ),
                  ),
                  // 嫩芽角标
                  if (isToday)
                    Positioned(
                      top: 6, right: 8,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Text('🌱', style: TextStyle(fontSize: 11))),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 试听弹窗
class _PreviewSheet extends StatefulWidget {
  final MusicWork work;
  const _PreviewSheet({required this.work});
  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late AnimationController _swayCtrl;
  StreamSubscription? _posSub, _durSub, _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _swayCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _stateSub = _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
      if (s.playing) { _swayCtrl.repeat(reverse: true); } else { _swayCtrl.stop(); _swayCtrl.value = 0; }
    });
    _posSub = _player.positionStream.listen((p) { if (mounted) setState(() => _pos = p); });
    _durSub = _player.durationStream.listen((d) { if (mounted) setState(() => _dur = d ?? Duration.zero); });
    _initPlay();
    Future.delayed(const Duration(milliseconds: 200), () async {
      await _player.setFilePath(widget.work.audioPath);
      if (mounted) await _player.play();
    });
  }

  Future<void> _initPlay() async {
    try {
      await _player.setFilePath(widget.work.audioPath);
      if (mounted) await _player.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel(); _durSub?.cancel(); _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    _swayCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // 摇摆小树
          AnimatedBuilder(
            animation: _swayCtrl,
            builder: (_, child) => Transform.rotate(angle: _swayCtrl.value * 0.08 - 0.04, child: child),
            child: CustomPaint(
              size: const Size(80, 80),
              painter: _MoodTreePainter(widget.work.moodSticker),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.work.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // 播放进度
          Row(children: [
            Text(_fmt(_pos), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                child: Slider(
                  value: _dur.inMilliseconds > 0 ? _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble() : 0,
                  max: _dur.inMilliseconds > 0 ? _dur.inMilliseconds.toDouble() : 1,
                  onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  activeColor: AppTheme.primaryGreen,
                ),
              ),
            ),
            Text(_fmt(_dur), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 12),
          // 播放按钮
          GestureDetector(
            onTap: () => _isPlaying ? _player.pause() : _player.play(),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)]),
                boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Center(child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28)),
            ),
          ),
          const SizedBox(height: 20),
          // 做成明信片
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('${AppRoutes.composeCard}?workId=${widget.work.id}');
              },
              icon: const Text('📮'),
              label: const Text('做成明信片'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryWarm, width: 1.5)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 长按菜单
class _WorkMenu extends StatelessWidget {
  final MusicWork work;
  const _WorkMenu({required this.work});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Text('✏️', style: TextStyle(fontSize: 22)),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _renameDialog(context);
            },
          ),
          ListTile(
            leading: const Text('🗑️', style: TextStyle(fontSize: 22)),
            title: const Text('删除'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认删除'),
                  content: Text('确定要删除「${work.title}」吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        context.read<AppState>().deleteWork(work.id);
                        Navigator.pop(context);
                      },
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Text('📋', style: TextStyle(fontSize: 22)),
            title: const Text('查看详情'),
            onTap: () {
              Navigator.pop(context);
              context.push('${AppRoutes.workDetail}?id=${work.id}');
            },
          ),
        ]),
      ),
    );
  }

  void _renameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: work.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, maxLength: 20, decoration: const InputDecoration(hintText: '输入新名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              context.read<AppState>().updateWork(work.copyWith(title: ctrl.text.trim()));
            }
            Navigator.pop(context);
          }, child: const Text('确定')),
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
            AppTheme.bgWarm.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.05),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

/// 心情小树插画 — CustomPainter 极简手绘风
class _MoodTreePainter extends CustomPainter {
  final MoodColor? mood;
  _MoodTreePainter(this.mood);

  static const _trunkBrown = Color(0xFFC4A882);
  static const _leafGreen = Color(0xFFB8D9A6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final trunk = Paint()..style=PaintingStyle.stroke..strokeWidth=3.5..strokeCap=StrokeCap.round;
    final fill = Paint()..style=PaintingStyle.fill;
    final line = Paint()..style=PaintingStyle.stroke..strokeWidth=2.5..strokeCap=StrokeCap.round;

    switch (mood) {
      case MoodColor.red: return _flowering(canvas, cx, cy, trunk, fill);
      case MoodColor.yellow: return _tender(canvas, cx, cy, trunk, fill);
      case MoodColor.green: return _quiet(canvas, cx, cy, trunk, fill, line);
      case MoodColor.blue: return _dandelion(canvas, cx, cy, trunk, fill, line);
      case MoodColor.purple: return _starSprout(canvas, cx, cy, trunk, fill);
      default: return _default(canvas, cx, cy, trunk, fill, line);
    }
  }

  void _flowering(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color=_trunkBrown; c.drawLine(Offset(cx,cy+22),Offset(cx,cy-10),t);
    f.color=const Color(0xFFC8E0B0); c.drawCircle(Offset(cx,cy-16),19,f); c.drawCircle(Offset(cx-9,cy-12),13,f); c.drawCircle(Offset(cx+9,cy-12),13,f);
    f.color=const Color(0xFFFFF0E0); c.drawCircle(Offset(cx-5,cy-23),4.5,f); c.drawCircle(Offset(cx+9,cy-20),4,f);
    f.color=const Color(0xFFFFE0D0); c.drawCircle(Offset(cx+3,cy-10),3.5,f);
    f.color=const Color(0xFFFFF8D0); c.drawCircle(Offset(cx-5,cy-23),1.5,f); c.drawCircle(Offset(cx+9,cy-20),1.2,f);
  }

  void _tender(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color=const Color(0xFFC8BCA0); c.drawLine(Offset(cx,cy+22),Offset(cx,cy-4),t);
    f.color=const Color(0xFFD0E8C0); final p=Path()..moveTo(cx,cy-4)..quadraticBezierTo(cx-22,cy-18,cx,cy-28)..quadraticBezierTo(cx+22,cy-18,cx,cy-4); c.drawPath(p,f);
    f.color=const Color(0xFFE4F4D8); final pi=Path()..moveTo(cx,cy-6)..quadraticBezierTo(cx-12,cy-14,cx,cy-20)..quadraticBezierTo(cx+12,cy-14,cx,cy-6); c.drawPath(pi,f);
  }

  void _quiet(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color=const Color(0xFFBAC8B4); t.strokeWidth=2.8; c.drawLine(Offset(cx,cy+24),Offset(cx,cy-6),t);
    l.color=const Color(0xFFBAC8B4); l.strokeWidth=2;
    c.drawLine(Offset(cx,cy-4),Offset(cx-12,cy-16),l); c.drawLine(Offset(cx,cy-4),Offset(cx+12,cy-16),l); c.drawLine(Offset(cx,cy-6),Offset(cx,cy-28),l);
    f.color=const Color(0xFFA4C6B4);
    void leaf(double x,double y,double r,double a){final p=Path()..moveTo(x,y)..quadraticBezierTo(x-r,y-r*1.8,x+a*3,y-r*1.4)..quadraticBezierTo(x+r,y-r*1.8,x,y); c.drawPath(p,f);}
    leaf(cx-12,cy-16,5.5,0.3); leaf(cx+12,cy-16,5.5,-0.3); leaf(cx-4,cy-22,4.5,0.1); leaf(cx+4,cy-22,4.5,-0.1); leaf(cx,cy-28,4,0);
  }

  void _dandelion(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color=const Color(0xFFD4C8A8); t.strokeWidth=3; c.drawLine(Offset(cx,cy+22),Offset(cx,cy-8),t);
    f.color=const Color(0xFFF0E8D0); c.drawCircle(Offset(cx,cy-16),18,f);
    f.color=const Color(0xFFF8F2E8).withValues(alpha:0.7); c.drawCircle(Offset(cx,cy-16),12,f);
    l.color=const Color(0xFFE8DDC8); l.strokeWidth=1.5;
    for(var i=0;i<8;i++){final a=(i/8)*2*3.14159; c.drawLine(Offset(cx+cos(a)*8,cy-16+sin(a)*8),Offset(cx+cos(a)*17,cy-16+sin(a)*17),l);}
    f.color=const Color(0xFFC8D8B0); final fl=Path()..moveTo(cx+22,cy-30)..quadraticBezierTo(cx+18,cy-38,cx+28,cy-36)..quadraticBezierTo(cx+24,cy-30,cx+22,cy-30); c.drawPath(fl,f);
  }

  void _starSprout(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color=const Color(0xFFC0C298); t.strokeWidth=3.2; c.drawLine(Offset(cx,cy+20),Offset(cx,cy-6),t);
    f.color=const Color(0xFFC0E0A8); final p=Path()..moveTo(cx,cy-6)..quadraticBezierTo(cx-16,cy-4,cx-4,cy-20)..quadraticBezierTo(cx+4,cy-14,cx,cy-6)..quadraticBezierTo(cx+4,cy-14,cx+4,cy-20)..quadraticBezierTo(cx+16,cy-4,cx,cy-6); c.drawPath(p,f);
    f.color=const Color(0xFFFFF8D0);
    void star(double x,double y,double r){final p=Path();for(var i=0;i<5;i++){final a=(i/5)*2*3.14159-3.14159/2;if(i==0)p.moveTo(x+cos(a)*r,y+sin(a)*r);else p.lineTo(x+cos(a)*r,y+sin(a)*r);p.lineTo(x+cos(a+3.14159/5)*r*0.4,y+sin(a+3.14159/5)*r*0.4);}p.close();c.drawPath(p,f);}
    star(cx-2,cy-26,3.5); star(cx+14,cy-18,2.5); star(cx-12,cy-16,2);
    f.color=const Color(0xFFFFFBE8); star(cx+6,cy-30,2); star(cx-8,cy-24,1.8);
  }

  void _default(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color=const Color(0xFFC4C4A8); t.strokeWidth=3; c.drawLine(Offset(cx,cy+22),Offset(cx,cy-4),t);
    f.color=const Color(0xFFC4DCB8); c.drawCircle(Offset(cx,cy-14),16,f); c.drawCircle(Offset(cx-8,cy-10),11,f); c.drawCircle(Offset(cx+8,cy-10),11,f);
    l.color=const Color(0xFFA4BC94); l.strokeWidth=1.5; c.drawLine(Offset(cx,cy-2),Offset(cx,cy-26),l);
  }

  @override
  bool shouldRepaint(covariant _MoodTreePainter o) => o.mood != mood;
}
