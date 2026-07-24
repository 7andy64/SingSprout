import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
                  color: AppTheme.primaryGreen.withOpacity(0.05),
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
class _WorkCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final durationStr = Formatters.formatDurationMinSec(work.duration);
    final dateStr = Formatters.formatDateShort(work.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppTheme.primaryGreen.withOpacity(0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: AppTheme.primaryGreen, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 选择模式下显示 checkbox
              if (selectMode) ...[
                GestureDetector(
                  onTap: onToggleSelect,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppTheme.primaryGreen
                          : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppTheme.primaryGreen : AppTheme.divider,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ],
              // 左侧封面
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    work.styleSeed.icon,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            work.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (work.isFavorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.favorite, size: 14, color: AppTheme.moodRed),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '${work.styleSeed.icon} ${work.styleSeed.label}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        if (work.moodSticker != null) ...[
                          const SizedBox(width: 6),
                          Text(work.moodSticker!.emoji, style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        Text(
                          durationStr,
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.8)),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧操作（非选择模式）
              if (!selectMode) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  onSelected: (action) {
                    if (action == 'favorite') onFavorite();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(
                            work.isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: work.isFavorite ? AppTheme.moodRed : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(work.isFavorite ? '取消收藏' : '收藏'),
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
}
