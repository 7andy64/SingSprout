import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/utils/formatters.dart';

/// 排序方式
enum WorkSortBy { newest, oldest, title, duration }

/// 筛选条件
enum WorkFilter { all, favorites, byModule }

/// 我的作品集 — 展示作品列表，支持批量选择/删除、排序、筛选
class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  bool _selectMode = false;
  final _selectedIds = <String>{};
  WorkSortBy _sortBy = WorkSortBy.newest;
  WorkFilter _filter = WorkFilter.all;
  String? _filterModule; // 当 filter 为 byModule 时使用

  List<MusicWork> _applySortAndFilter(List<MusicWork> works) {
    var result = List<MusicWork>.of(works);

    // 筛选
    switch (_filter) {
      case WorkFilter.all:
        break;
      case WorkFilter.favorites:
        result = result.where((w) => w.isFavorite).toList();
        break;
      case WorkFilter.byModule:
        if (_filterModule != null) {
          result = result.where((w) => w.sourceModule == _filterModule).toList();
        }
        break;
    }

    // 排序
    switch (_sortBy) {
      case WorkSortBy.newest:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case WorkSortBy.oldest:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case WorkSortBy.title:
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case WorkSortBy.duration:
        result.sort((a, b) => a.duration.inSeconds.compareTo(b.duration.inSeconds));
        break;
    }

    return result;
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      if (_selectedIds.isEmpty) _selectMode = false;
    });
  }

  void _enterSelectMode(String id) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    final ids = List<String>.of(_selectedIds);
    if (ids.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${ids.length} 首作品吗？\n删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final appState = context.read<AppState>();
    for (final id in ids) {
      await appState.deleteWork(id);
    }
    _exitSelectMode();
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('排序方式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...WorkSortBy.values.map((s) => ListTile(
              leading: Icon(
                _sortBy == s ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _sortBy == s ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
              title: Text(_sortLabel(s)),
              onTap: () {
                setState(() => _sortBy = s);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('筛选', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: Icon(
                _filter == WorkFilter.all ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _filter == WorkFilter.all ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
              title: const Text('全部作品'),
              onTap: () {
                setState(() => _filter = WorkFilter.all);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                _filter == WorkFilter.favorites ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _filter == WorkFilter.favorites ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
              title: const Text('仅收藏'),
              onTap: () {
                setState(() => _filter = WorkFilter.favorites);
                Navigator.pop(ctx);
              },
            ),
            ...StyleSeed.values.map((seed) => ListTile(
              leading: Icon(
                _filter == WorkFilter.byModule && _filterModule == 'humming_garden'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _filter == WorkFilter.byModule && _filterModule == 'humming_garden'
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
              title: Text('${seed.icon}  ${seed.label} 风格'),
              onTap: () {
                setState(() {
                  _filter = WorkFilter.byModule;
                  _filterModule = 'humming_garden';
                });
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(WorkSortBy s) {
    switch (s) {
      case WorkSortBy.newest: return '最新优先';
      case WorkSortBy.oldest: return '最早优先';
      case WorkSortBy.title: return '按标题';
      case WorkSortBy.duration: return '按时长';
    }
  }

  String get _filterLabel {
    switch (_filter) {
      case WorkFilter.all: return '全部';
      case WorkFilter.favorites: return '已收藏';
      case WorkFilter.byModule: return '哼唱花园';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final allWorks = appState.works;
        final works = _applySortAndFilter(allWorks);

        return Scaffold(
          appBar: AppBar(
            title: Text(_selectMode ? '已选 ${_selectedIds.length} 项' : '我的作品集'),
            centerTitle: true,
            leading: _selectMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectMode,
                  )
                : null,
            actions: _selectMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _selectedIds.isNotEmpty ? _batchDelete : null,
                      tooltip: '删除选中',
                    ),
                    _MenuAnchor(
                      icon: Icons.more_vert,
                      items: [
                        _MenuEntry(
                          label: '全选',
                          onTap: () => setState(() {
                            _selectedIds.addAll(works.map((w) => w.id));
                          }),
                        ),
                        _MenuEntry(
                          label: '取消全选',
                          onTap: () => setState(() => _selectedIds.clear()),
                        ),
                      ],
                    ),
                  ]
                : [
                    _MenuAnchor(
                      icon: Icons.sort_rounded,
                      items: [
                        _MenuEntry(label: '排序', onTap: _showSortSheet),
                        _MenuEntry(label: '筛选', onTap: _showFilterSheet),
                      ],
                    ),
                  ],
          ),
          body: Column(
            children: [
              // 筛选状态指示条
              if (_filter != WorkFilter.all)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Text(
                        '筛选: $_filterLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (allWorks.length != works.length) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${works.length}/${allWorks.length})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _filter = WorkFilter.all),
                        child: const Text(
                          '清除',
                          style: TextStyle(fontSize: 13, color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                ),

              // 作品列表
              Expanded(
                child: works.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: works.length,
                        itemBuilder: (_, i) {
                          final w = works[i];
                          final selected = _selectedIds.contains(w.id);
                          return _WorkCard(
                            work: w,
                            selected: selected,
                            selectMode: _selectMode,
                            onFavorite: () => appState.toggleFavorite(w.id),
                            onDelete: () => _confirmDelete(context, w),
                            onTap: () {
                              if (_selectMode) {
                                _toggleSelect(w.id);
                              } else {
                                context.push('${AppRoutes.workDetail}?id=${w.id}');
                              }
                            },
                            onLongPress: () {
                              if (!_selectMode) _enterSelectMode(w.id);
                            },
                            onToggleSelect: () => _toggleSelect(w.id),
                          );
                        },
                      ),
              ),
            ],
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
          const Text('🎵', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            _filter != WorkFilter.all ? '没有符合条件的作品' : '还没有作品',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter != WorkFilter.all ? '试试调整筛选条件' : '去哼唱花园录制你的第一首歌吧',
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MusicWork work) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除作品'),
        content: Text('确定要删除「${work.title}」吗？\n删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteWork(work.id);
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

/// 弹出菜单锚点
class _MenuAnchor extends StatelessWidget {
  final IconData icon;
  final List<_MenuEntry> items;

  const _MenuAnchor({required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(icon),
      onSelected: (label) {
        final entry = items.firstWhere((e) => e.label == label);
        entry.onTap();
      },
      itemBuilder: (_) => items
          .map((e) => PopupMenuItem<String>(value: e.label, child: Text(e.label)))
          .toList(),
    );
  }
}

class _MenuEntry {
  final String label;
  final VoidCallback onTap;
  const _MenuEntry({required this.label, required this.onTap});
}

/// 作品卡片
///
/// 包含：可辨识的圆形播放/暂停按钮（根据播放状态切换）、真实录音时长、
/// 收藏状态高亮。收藏作品以金色左边框 + 星标徽章区分。
class _WorkCard extends StatefulWidget {
  final MusicWork work;
  final bool selected;
  final bool selectMode;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  const _WorkCard({
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
  State<_WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<_WorkCard>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0.0;

  /// 脉冲动画控制器 — 播放时按钮有呼吸效果
  late final AnimationController _pulseCtrl;

  /// 全局唯一活跃播放器
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
              // 选择模式：checkbox
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
                            // 进度环（仅播放时可见）
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
                            // 按钮本体
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
                    // 标题行 + 收藏星标
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
                        // 收藏星标
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

                    // 信息行：风格 + 心情 + 时长 + 日期
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

              // ── 右侧操作 ──
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
