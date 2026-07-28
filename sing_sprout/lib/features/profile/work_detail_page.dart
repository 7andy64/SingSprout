import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/utils/formatters.dart';

/// 作品详情 / 播放页
///
/// 从作品列表点击进入，支持试听、编辑标题/备注、收藏、删除和分享为明信片。
class WorkDetailPage extends StatefulWidget {
  final String workId;

  const WorkDetailPage({super.key, required this.workId});

  @override
  State<WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends State<WorkDetailPage> {
  final _player = AudioPlayer();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  MusicWork? _work;
  bool _isPlaying = false;
  bool _isEditing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadWork();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadWork() {
    final appState = context.read<AppState>();
    _work = appState.works.where((w) => w.id == widget.workId).firstOrNull;
    if (_work == null) return;

    _titleController.text = _work!.title;
    _noteController.text = _work!.note ?? '';

    // 初始化音频播放器
    final path = _work!.audioPath;
    if (path.isNotEmpty) {
      try {
        _player.setFilePath(path);
      } catch (_) {
        // 文件不可用时静默处理
      }
    }
  }

  // ── 编辑 ──

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      // 退出编辑时保存
      _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    if (_work == null) return;
    final newTitle = _titleController.text.trim();
    final newNote = _noteController.text.trim();

    if (newTitle.isEmpty) return;
    if (newTitle == _work!.title && newNote == (_work!.note ?? '')) return;

    final updated = _work!.copyWith(title: newTitle, note: newNote.isNotEmpty ? newNote : null);
    await context.read<AppState>().updateWork(updated);
    setState(() => _work = updated);
  }

  // ── 播放控制 ──

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekTo(double value) {
    _player.seek(Duration(seconds: value.toInt()));
  }

  String _positionText() {
    final m = _position.inMinutes;
    final s = _position.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _durationText() {
    final m = _duration.inMinutes;
    final s = _duration.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── 操作 ──

  Future<void> _toggleFavorite() async {
    if (_work == null) return;
    await context.read<AppState>().toggleFavorite(_work!.id);
    setState(() {
      _work = _work!.copyWith(isFavorite: !_work!.isFavorite);
    });
  }

  void _confirmDelete() {
    if (_work == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除作品'),
        content: Text('确定要删除「${_work!.title}」吗？\n删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteWork(_work!.id);
              if (mounted) Navigator.pop(ctx); // 关闭对话框
              if (mounted) context.pop(); // 返回列表
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _shareAsCard() {
    if (_work == null) return;
    // 跳转到明信片编辑页，预填作品信息
    context.push('${AppRoutes.composeCard}?workId=${_work!.id}');
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    if (_work == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('作品详情')),
        body: const Center(child: Text('作品不存在')),
      );
    }

    final work = _work!;

    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      appBar: AppBar(
        title: _isEditing ? const Text('编辑作品') : const Text('作品详情'),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
              onPressed: _toggleEdit,
            ),
          if (_isEditing)
            TextButton(
              onPressed: _toggleEdit,
              child: const Text('完成'),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── 封 面 区 ──
            _buildCover(work),
            const SizedBox(height: 12),

            // ── 标 题 ──
            if (_isEditing)
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '作品标题',
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              )
            else
              Text(
                work.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),

            // ── 播 放 器 ──
            _buildPlayer(),
            const SizedBox(height: 20),

            // ── 元 数 据 卡 ──
            _buildMetadata(work),
            const SizedBox(height: 20),

            // ── 备 注 ──
            if (_isEditing)
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注 / 创作故事',
                  border: OutlineInputBorder(),
                  hintText: '记录创作时的心情或想法...',
                ),
                maxLines: 3,
                maxLength: 200,
              )
            else if ((work.note ?? '').isNotEmpty)
              _buildNoteSection(work.note!),
          ],
        ),
      ),
      // ── 底 部 操 作 栏 ──
      bottomNavigationBar: _buildBottomBar(context, work),
    );
  }

  Widget _buildCover(MusicWork work) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA8E6CF), Color(0xFFDCEDC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          work.styleSeed.icon,
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final progress = _duration.inSeconds > 0
        ? _position.inSeconds / _duration.inSeconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: AppTheme.primaryGreen,
              inactiveTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
              thumbColor: AppTheme.primaryGreen,
              overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: _duration.inSeconds > 0 ? (v) {
                _seekTo(v * _duration.inSeconds);
              } : null,
            ),
          ),
          // 时间 + 播放按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _positionText(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              // 播放/暂停
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              Text(
                _durationText(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(MusicWork work) {
    return Row(
      children: [
        _MetaChip(
          icon: Icons.palette_outlined,
          label: work.styleSeed.icon + ' ' + work.styleSeed.label,
        ),
        const SizedBox(width: 8),
        if (work.moodSticker != null) ...[
          _MetaChip(
            icon: Icons.emoji_emotions_outlined,
            label: '${work.moodSticker!.emoji} ${work.moodSticker!.label}',
          ),
          const SizedBox(width: 8),
        ],
        _MetaChip(
          icon: Icons.access_time,
          label: Formatters.formatDuration(work.duration),
        ),
      ],
    );
  }

  Widget _buildNoteSection(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                '创作故事',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, MusicWork work) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 收藏
            _ActionButton(
              icon: work.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: work.isFavorite ? AppTheme.moodRed : AppTheme.textSecondary,
              label: work.isFavorite ? '已收藏' : '收藏',
              onTap: _toggleFavorite,
            ),
            const SizedBox(width: 12),
            // 分享明信片
            Expanded(
              child: FilledButton.icon(
                onPressed: _shareAsCard,
                icon: const Icon(Icons.mail_outline, size: 20),
                label: const Text('制作明信片'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 元数据标签
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
