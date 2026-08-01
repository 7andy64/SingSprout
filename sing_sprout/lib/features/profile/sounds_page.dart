import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/sound_sample.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/audio_service.dart';

/// 我的声音库 — 展示田野声音实验室采集的声音样本，支持点击播放
class SoundsPage extends StatefulWidget {
  const SoundsPage({super.key});

  @override
  State<SoundsPage> createState() => _SoundsPageState();
}

class _SoundsPageState extends State<SoundsPage>
    with TickerProviderStateMixin {
  final _audioService = AudioService();
  String? _playingId;
  bool _isPlaying = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _waveCtrl;

  SoundType? _filterType; // null = 全部
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();

    // 容器入场微动画 — 柔和呼吸感
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);

    // 波形跳动动画 — 连续循环
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _waveCtrl.repeat();
  }

  @override
  void dispose() {
    _audioService.stopPlayback();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(SoundSample sound) async {
    if (_playingId == sound.id) {
      // Same sound: toggle play/pause
      if (_isPlaying) {
        await _audioService.pausePlayback();
        setState(() => _isPlaying = false);
      } else {
        await _audioService.resumePlayback();
        setState(() => _isPlaying = true);
      }
    } else {
      // Different sound: stop current, start new
      await _audioService.stopPlayback();
      await _audioService.playAudio(sound.audioPath);
      setState(() {
        _playingId = sound.id;
        _isPlaying = true;
      });
    }
  }

  Future<void> _stopPlayback() async {
    await _audioService.stopPlayback();
    setState(() {
      _playingId = null;
      _isPlaying = false;
    });
  }

  List<SoundSample> _filteredSounds(List<SoundSample> all) {
    if (_filterType == null) return all;
    return all.where((s) => s.type == _filterType).toList();
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '全部',
              selected: _filterType == null,
              onTap: () => setState(() => _filterType = null),
            ),
            ...SoundType.values.map(
              (t) => _FilterChip(
                label: t.label,
                selected: _filterType == t,
                onTap: () => setState(() =>
                    _filterType = _filterType == t ? null : t),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundGrid(List<SoundSample> sounds) {
    final filtered = _filteredSounds(sounds);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _filterType == null ? '🎤' : '🔍',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              _filterType == null ? '还没有采集声音' : '该分类下暂无声音',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final s = filtered[i];
        final isDeleting = _deletingIds.contains(s.id);
        return _DeletingCardWrapper(
          isDeleting: isDeleting,
          child: _SoundCard(
            sound: s,
            isPlaying: _playingId == s.id && _isPlaying,
            isActive: _playingId == s.id,
            waveCtrl: _waveCtrl,
            onPlay: () => _togglePlay(s),
            onShare: () => _onShare(s),
            onDelete: () => _showDeleteDialog(s),
            onRename: () => _showRenameDialog(s),
          ),
        );
      },
    );
  }

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
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _SoundStatsHeader(
                        total: sounds.length,
                        pulseAnim: _pulseAnim,
                      ),
                      _buildTypeFilter(),
                      Expanded(
                        child: _buildSoundGrid(sounds),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎤', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            '还没有采集声音',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '去田野声音实验室采集你的第一个声音吧',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _onShare(SoundSample sound) {
    SharePlus.instance.share(
      ShareParams(
        text: '来听听我在「声芽」里采集的声音：${sound.name} 🎵',
        subject: sound.name,
      ),
    );
  }

  void _showRenameDialog(SoundSample sound) {
    final controller = TextEditingController(text: sound.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重命名声音', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '声音名称',
            hintText: '输入新名称',
          ),
          maxLength: 20,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () { controller.dispose(); Navigator.pop(ctx); },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              controller.dispose();
              if (newName.isNotEmpty && newName != sound.name) {
                await context.read<AppState>().updateSound(sound.copyWith(name: newName));
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SoundSample sound) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🗑️', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('删除声音', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          '你确定要删除这个声音吗？删除后就找不回来了哦。',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('❌ 取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleDeleteConfirmed(sound);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('✅ 确定删除'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteConfirmed(SoundSample sound) {
    if (_playingId == sound.id) _stopPlayback();

    setState(() => _deletingIds.add(sound.id));

    // 等删除动画播完后再真正删除 + 提示
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      context.read<AppState>().deleteSound(sound.id);
      setState(() => _deletingIds.remove(sound.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                '已删除',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
}

/// 声音库顶部统计卡片 — 圆角容器 + 数字微动画
class _SoundStatsHeader extends StatelessWidget {
  final int total;
  final Animation<double> pulseAnim;

  const _SoundStatsHeader({required this.total, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnim.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF5B9A4B),
              Color(0xFF7ABD6A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧：数字计数
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '声音总数',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _AnimatedCount(target: total),
                  const SizedBox(height: 2),
                  Text(
                    total == 0 ? '去田野采集第一个声音吧 🌿' : '个声音',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            // 右侧：装饰图标
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🎵', style: TextStyle(fontSize: 26)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数字递增动画 — 使用 TweenAnimationBuilder 实现流畅跳动
class _AnimatedCount extends StatelessWidget {
  final int target;

  const _AnimatedCount({required this.target});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        );
      },
    );
  }
}

/// 分类筛选芯片
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.primaryGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(
                    color: AppTheme.divider,
                  ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 删除动画包裹器 — 卡片缩小淡出
class _DeletingCardWrapper extends StatefulWidget {
  final bool isDeleting;
  final Widget child;

  const _DeletingCardWrapper({
    required this.isDeleting,
    required this.child,
  });

  @override
  State<_DeletingCardWrapper> createState() => _DeletingCardWrapperState();
}

class _DeletingCardWrapperState extends State<_DeletingCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInBack),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void didUpdateWidget(covariant _DeletingCardWrapper old) {
    super.didUpdateWidget(old);
    if (!old.isDeleting && widget.isDeleting) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDeleting && !_ctrl.isAnimating) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// 声音样本卡片 — 网格竖向布局，底部三按钮操作栏
class _SoundCard extends StatelessWidget {
  final SoundSample sound;
  final bool isPlaying;
  final bool isActive;
  final AnimationController waveCtrl;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _SoundCard({
    required this.sound,
    required this.isPlaying,
    required this.isActive,
    required this.waveCtrl,
    required this.onPlay,
    required this.onShare,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部：图标 + 类型标签
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _typeColor(sound.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _typeEmoji(sound.type),
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor(sound.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sound.type.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: _typeColor(sound.type),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 声音名称
              Text(
                sound.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 波形动画 / 占位区
              _WaveBars(
                waveCtrl: waveCtrl,
                isActive: isActive,
                isPlaying: isPlaying,
                barColor: _typeColor(sound.type),
              ),
              const SizedBox(height: 8),

              // 日期
              Text(
                Formatters.formatDateShort(sound.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // 底部操作栏：▶ 播放 / ✏️ 重命名 / 📤 分享 / 🗑️ 删除
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionButton(
                    icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    label: isPlaying ? '暂停' : '播放',
                    color: AppTheme.primaryGreen,
                    onTap: onPlay,
                  ),
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: '重命名',
                    color: const Color(0xFF7C4DFF),
                    onTap: onRename,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: '分享',
                    color: const Color(0xFF4D96FF),
                    onTap: onShare,
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: AppTheme.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return const Color(0xFFFF6B6B);
      case SoundType.animal: return const Color(0xFFFFB347);
      case SoundType.nature: return AppTheme.primaryGreen;
      case SoundType.mechanical: return const Color(0xFF7C4DFF);
      case SoundType.unknown: return AppTheme.textSecondary;
    }
  }

  String _typeEmoji(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return '🗣️';
      case SoundType.animal: return '🐾';
      case SoundType.nature: return '🌿';
      case SoundType.mechanical: return '⚙️';
      case SoundType.unknown: return '❓';
    }
  }
}

/// 单个操作按钮 — 图标 + 文字
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片内波形跳动动画 — 播放时跳动，暂停时静止
class _WaveBars extends StatelessWidget {
  final AnimationController waveCtrl;
  final bool isActive;
  final bool isPlaying;
  final Color barColor;

  const _WaveBars({
    required this.waveCtrl,
    required this.isActive,
    required this.isPlaying,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      // 未激活：占位高度，保持卡片高度一致
      return const SizedBox(height: 28);
    }

    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: waveCtrl,
        builder: (context, _) {
          final t = waveCtrl.value * 2 * 3.1415926535; // 0 … 2π
          return CustomPaint(
            size: const Size(double.infinity, 28),
            painter: _WavePainter(
              phase: t,
              isPlaying: isPlaying,
              color: barColor,
            ),
          );
        },
      ),
    );
  }
}

/// 波形绘制器 — 10 根竖条，相位偏移制造波浪感
class _WavePainter extends CustomPainter {
  final double phase;
  final bool isPlaying;
  final Color color;

  _WavePainter({
    required this.phase,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 10;
    const barWidth = 3.0;
    final gap = (size.width - barCount * barWidth) / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      // 每根条独立相位，产生波浪效果
      final barPhase = phase + i * 0.7;
      final raw = (0.5 + 0.5 * (barPhase));
      // 播放时全振幅，暂停时缩到 0.25 倍
      final amplitude = isPlaying ? 1.0 : 0.25;
      final height = (raw * size.height * 0.85).clamp(4.0, size.height) * amplitude;

      final x = gap + i * (barWidth + gap);
      final y = size.height - height;

      final paint = Paint()
        ..color = isPlaying
            ? color.withValues(alpha: 0.55 + 0.45 * raw)
            : color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;

      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, height),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      phase != old.phase || isPlaying != old.isPlaying || color != old.color;
}
