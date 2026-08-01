import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/connectivity_provider.dart';
import '../../shared/services/outbox_queue_service.dart';
import '../../shared/utils/postcard_generator.dart';

/// 撰写音乐明信片 — 选择作品 + 写一句话 → 生成卡片 → 微信分享
class ComposePage extends StatefulWidget {
  final String? initialWorkId;
  const ComposePage({super.key, this.initialWorkId});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _messageController = TextEditingController();
  MusicWork? _selectedWork;
  bool _generating = false;

  List<MusicWork> get _works {
    final appState = context.read<AppState>();
    return appState.works;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkId != null) {
      // 从路由参数预选作品
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appState = context.read<AppState>();
        final work = appState.works
            .where((w) => w.id == widget.initialWorkId)
            .firstOrNull;
        if (work != null && mounted) {
          setState(() => _selectedWork = work);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _generateAndShare() async {
    if (_selectedWork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一首作品')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final appState = context.read<AppState>();
      final profile = appState.userProfile;
      final senderName = profile?.nickname ?? '声芽用户';
      final isOnline = context.read<ConnectivityProvider>().isConnected;

      // 1. 生成明信片图片
      final imagePath = await PostcardGenerator.generate(
        work: _selectedWork!,
        message: _messageController.text.trim(),
        senderName: senderName,
      );

      // 2. 保存明信片记录
      final card = VoiceCard.send(
        senderId: profile?.localId ?? 'anonymous',
        workId: _selectedWork!.id,
        audioPath: _selectedWork!.audioPath,
        textContent: _messageController.text.trim(),
        coverUrl: imagePath,
      );
      await appState.addVoiceCard(card);

      if (!mounted) return;

      if (isOnline) {
        // 3. 在线：直接分享
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '🎵 ${_selectedWork!.title} — ${_messageController.text.trim()}',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('明信片已生成，可通过微信分享给家人')),
        );
      } else {
        // 3. 离线：缓存到发件箱
        await OutboxQueueService().enqueue(card);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到发件箱，联网后自动发送')),
        );
      }
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: const Text('写音乐明信片'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择音乐作品
              const Text(
                '选择一首作品',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _works.isNotEmpty ? _WorkSelector(
                works: _works,
                selected: _selectedWork,
                onSelected: (w) => setState(() => _selectedWork = w),
              ) : Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.06),
                      AppTheme.primaryWarm.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '还没有作品，先去哼唱花园创作吧',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 写给谁
              const Text(
                '想说的话',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLength: 100,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '比如：妈妈我好想你...',
                ),
              ),
              if (_messageController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '预览: ${_messageController.text.length > 30 ? '${_messageController.text.substring(0, 30)}...' : _messageController.text}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),

              const Spacer(),

              // 预览与发送
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generateAndShare,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('📤', style: TextStyle(fontSize: 20)),
                  label: Text(_generating ? '生成中...' : '生成明信片并分享'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '将通过微信发送给爸爸妈妈',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 作品选择器 — 横向滚动的作品卡片列表
class _WorkSelector extends StatelessWidget {
  final List<MusicWork> works;
  final MusicWork? selected;
  final ValueChanged<MusicWork> onSelected;

  const _WorkSelector({
    required this.works,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final work = works[index];
          final isSelected = work.id == selected?.id;
          return GestureDetector(
            onTap: () => onSelected(work),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                    : AppTheme.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    work.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${work.styleSeed.label} · ${_formatShort(work.duration)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatShort(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
