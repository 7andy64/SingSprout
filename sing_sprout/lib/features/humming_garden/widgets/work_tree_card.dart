import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/music_work.dart';
import '../../../shared/providers/app_state.dart';
import 'mood_tree_painter.dart';
import 'preview_sheet.dart';

Color moodBgColor(MoodColor? mood) {
  switch (mood) {
    case MoodColor.red:
      return const Color(0xFFFFF0E8);
    case MoodColor.yellow:
      return const Color(0xFFFFF8E0);
    case MoodColor.green:
      return const Color(0xFFE8F5E9);
    case MoodColor.blue:
      return const Color(0xFFE8F0FD);
    case MoodColor.purple:
      return const Color(0xFFF3E5F5);
    case MoodColor.grey:
      return const Color(0xFFF5F5F5);
    case null:
      return const Color(0xFFF5F5F5);
  }
}

// ═══ Empty works placeholder ═══

class EmptyWorksPlaceholder extends StatelessWidget {
  const EmptyWorksPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),),
      ),
      child: Column(children: [
        const Text('🌱', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('还没有作品',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,),),
        const SizedBox(height: 4),
        const Text('去创作页录制你的第一首歌吧',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,),),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.creativeFlow),
          icon: const Text('🌿', style: TextStyle(fontSize: 16)),
          label: const Text('立即创作'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),),
          ),
        ),
      ],),
    );
  }
}

// ═══ Work tree card ═══

class WorkTreeCard extends StatefulWidget {
  final MusicWork work;
  final int delayMs;
  const WorkTreeCard({super.key, required this.work, this.delayMs = 0});

  @override
  State<WorkTreeCard> createState() => _WorkTreeCardState();
}

class _WorkTreeCardState extends State<WorkTreeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeSlideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _fadeSlideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400),);
    _fadeAnim =
        CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero,)
        .animate(
            CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut),);
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
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),),
      builder: (_) => PreviewSheet(work: widget.work),
    );
  }

  void _showContextMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),),
      builder: (_) => WorkMenu(work: widget.work),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = moodBgColor(widget.work.moodSticker);
    final isToday = widget.work.createdAt.year == DateTime.now().year &&
        widget.work.createdAt.month == DateTime.now().month &&
        widget.work.createdAt.day == DateTime.now().day;
    final timeStr =
        '${widget.work.createdAt.hour.toString().padLeft(2, '0')}:${widget.work.createdAt.minute.toString().padLeft(2, '0')}';
    final moodLabel = widget.work.moodSticker?.label ?? '未标记';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: _showPreview,
          onLongPressStart: (_) => setState(() => _isPressed = true),
          onLongPressEnd: (_) {
            setState(() => _isPressed = false);
            _showContextMenu();
          },
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
                    color: (_isPressed
                            ? AppTheme.primaryGreen
                            : Colors.black)
                        .withValues(
                            alpha: _isPressed ? 0.15 : 0.06,),
                    blurRadius: _isPressed ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(children: [
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: CustomPaint(
                        size: const Size(72, 72),
                        painter: MoodTreePainter(
                            widget.work.moodSticker,),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Column(children: [
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),),),
                    const SizedBox(height: 2),
                    Text(moodLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),),),
                  ],),
                ),
                if (isToday)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child: Text('🌱',
                              style: TextStyle(fontSize: 11),),),
                    ),
                  ),
              ],),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ Work menu ═══

class WorkMenu extends StatelessWidget {
  final MusicWork work;
  const WorkMenu({super.key, required this.work});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),),),
          const SizedBox(height: 16),
          ListTile(
            leading: const Text('✏️',
                style: TextStyle(fontSize: 22),),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _renameDialog(context);
            },
          ),
          ListTile(
            leading: const Text('🗑️',
                style: TextStyle(fontSize: 22),),
            title: const Text('删除'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认删除'),
                  content:
                      Text('确定要删除「${work.title}」吗？'),
                  actions: [
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        child: const Text('取消'),),
                    FilledButton(
                      onPressed: () {
                        context
                            .read<AppState>()
                            .deleteWork(work.id);
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
            leading: const Text('📋',
                style: TextStyle(fontSize: 22),),
            title: const Text('查看详情'),
            onTap: () {
              Navigator.pop(context);
              context.push(
                  '${AppRoutes.workDetail}?id=${work.id}',);
            },
          ),
        ],),
      ),
    );
  }

  void _renameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: work.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
            controller: ctrl,
            maxLength: 20,
            decoration:
                const InputDecoration(hintText: '输入新名称'),),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),),
          FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  context.read<AppState>().updateWork(
                      work.copyWith(title: ctrl.text.trim()),);
                }
                Navigator.pop(context);
              },
              child: const Text('确定'),),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }
}
