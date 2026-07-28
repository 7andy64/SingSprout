import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/music_work.dart';
import '../../../shared/utils/formatters.dart';

/// 作品卡片
///
/// 包含：可辨识的圆形播放/暂停按钮（根据播放状态切换）、真实录音时长、
/// 收藏状态高亮。收藏作品以金色左边框 + 星标徽章区分。
class WorkCard extends StatefulWidget {
  final MusicWork work;
  final bool selected;
  final bool selectMode;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  const WorkCard({
    super.key,
    required this.work,
    required this.selected,
    required this.selectMode,
    required this.onFavorite,
    required this.onDelete,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0.0;

  late final AnimationController _pulseCtrl;

  static _WorkCardState? _activePlayer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _player.positionStream.listen((pos) {
      final dur = _player.duration ?? Duration.zero;
      if (dur.inMilliseconds > 0 && mounted) {
        setState(() => _progress = pos.inMilliseconds / dur.inMilliseconds);
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _progress = 0;
          });
          _pulseCtrl.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    if (_activePlayer == this) _activePlayer = null;
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_activePlayer != null && _activePlayer != this) {
      await _activePlayer!._stop();
    }
    if (_isPlaying) {
      await _stop();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    try {
      await _player.setFilePath(widget.work.audioPath);
      await _player.play();
      if (mounted) {
        setState(() => _isPlaying = true);
        _pulseCtrl.repeat(reverse: true);
      }
      _activePlayer = this;
    } catch (e) {
      debugPrint('[WorkCard] 播放失败: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _progress = 0;
      });
      _pulseCtrl.reverse();
    }
    if (_activePlayer == this) _activePlayer = null;
  }

  @override
  Widget build(BuildContext context) {
    final durationStr = _formatDuration(widget.work.duration);
    final dateStr = Formatters.formatDateShort(widget.work.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: widget.selected
          ? AppTheme.primaryGreen.withValues(alpha: 0.06)
          : (widget.work.isFavorite ? const Color(0xFFFFF8E1) : null),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.selected
            ? const BorderSide(color: AppTheme.primaryGreen, width: 1.5)
            : (widget.work.isFavorite
                ? const BorderSide(color: Color(0xFFFFB300), width: 1.2)
                : BorderSide.none),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (widget.selectMode) ...[
                GestureDetector(
                  onTap: widget.onToggleSelect,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? AppTheme.primaryGreen
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.selected ? AppTheme.primaryGreen : AppTheme.divider,
                        width: 2,
                      ),
                    ),
                    child: widget.selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ],

              // ── 左侧：圆形播放/暂停按钮（带进度环 + 脉冲呼吸） ──
              GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    final pulseScale = _isPlaying ? 1.0 + _pulseCtrl.value * 0.06 : 1.0;
                    return Transform.scale(
                      scale: pulseScale,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isPlaying)
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  value: _progress.clamp(0.0, 1.0),
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B6B),
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              width: _isPlaying ? 48 : 56,
                              height: _isPlaying ? 48 : 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isPlaying
                                      ? const [Color(0xFFFF6B6B), Color(0xFFD32F2F)]
                                      : const [Color(0xFF7BC67E), Color(0xFF4A8A3B)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isPlaying
                                            ? const Color(0xFFFF6B6B)
                                            : const Color(0xFF6BAF4B))
                                        .withValues(alpha: _isPlaying ? 0.4 : 0.3),
                                    blurRadius: _isPlaying ? 16 : 10,
                                    spreadRadius: _isPlaying ? 2 : 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: _isPlaying ? 26 : 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // ── 中间信息 ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.work.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.work.isFavorite)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 14, color: Color(0xFFFF8F00)),
                                SizedBox(width: 2),
                                Text(
                                  '已收藏',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFFF8F00),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Text(
                          '${widget.work.styleSeed.icon} ${widget.work.styleSeed.label}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        if (widget.work.moodSticker != null) ...[
                          const SizedBox(width: 6),
                          Text(widget.work.moodSticker!.emoji, style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_filled,
                            size: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!widget.selectMode) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  onSelected: (action) {
                    if (action == 'favorite') widget.onFavorite();
                    if (action == 'delete') widget.onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(
                            widget.work.isFavorite ? Icons.star : Icons.star_border,
                            size: 18,
                            color: widget.work.isFavorite
                                ? const Color(0xFFFF8F00)
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(widget.work.isFavorite ? '取消收藏' : '收藏'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Text('删除'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    if (totalSec <= 0) return '0:01';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
