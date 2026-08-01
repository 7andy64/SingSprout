import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';

/// 明信片详情页 — 查看、标记已读、回复、删除
class CardDetailPage extends StatefulWidget {
  final String cardId;
  const CardDetailPage({super.key, required this.cardId});

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsReadIfNeeded();
    });
  }

  void _markAsReadIfNeeded() {
    final appState = context.read<AppState>();
    final card = appState.cards.where((c) => c.id == widget.cardId).firstOrNull;
    if (card != null && card.isUnread) {
      appState.markCardAsRead(card.id);
    }
  }

  Future<void> _deleteCard(VoiceCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除明信片'),
        content: const Text('删除后无法恢复，确定要删除这张明信片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final appState = context.read<AppState>();
      await appState.deleteVoiceCard(card.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('明信片已删除')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final card = appState.cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('明信片')),
        body: const Center(child: Text('明信片不存在或已被删除')),
      );
    }

    final work = appState.works.where((w) => w.id == card.workId).firstOrNull;
    final isReceived = card.direction == VoiceCardDirection.received;

    return Scaffold(
      appBar: AppBar(
        title: Text(isReceived ? '收到的明信片' : '发出的明信片'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
            onPressed: () => _deleteCard(card),
            tooltip: '删除',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 明信片图片
            if (card.coverUrl != null && File(card.coverUrl!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(card.coverUrl!),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),

            if (card.coverUrl == null || !File(card.coverUrl!).existsSync())
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.15),
                      AppTheme.primaryWarm.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      work?.styleSeed.icon ?? '🎵',
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      work?.title ?? '音乐明信片',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // 作品信息
            if (work != null) ...[
              _InfoRow(label: '作品', value: work.title),
              _InfoRow(label: '风格', value: '${work.styleSeed.label} · ${_formatDuration(work.duration)}'),
              const SizedBox(height: 16),
            ],

            // 留言
            if (card.textContent != null && card.textContent!.isNotEmpty) ...[
              const _SectionLabel(label: '想说的话'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  card.textContent!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],

            // 语音祝福
            if (card.greetingText != null && card.greetingText!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionLabel(label: '🎙️ 语音祝福'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryWarm.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.greetingText!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GreetingPlayer(audioPath: card.greetingAudioPath),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 状态信息
            _InfoRow(label: '发送时间', value: _formatDate(card.createdAt)),
            if (isReceived && card.readAt != null)
              _InfoRow(label: '已读时间', value: _formatDate(card.readAt!)),
            if (isReceived && card.isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '未读',
                  style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 32),

            // 操作按钮
            if (isReceived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push(
                      '${AppRoutes.composeCard}?workId=${card.workId}&replyToId=${card.id}',
                    );
                  },
                  icon: const Text('💌', style: TextStyle(fontSize: 20)),
                  label: const Text('回复这张明信片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: AppTheme.textPrimary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _GreetingPlayer extends StatefulWidget {
  final String? audioPath;
  const _GreetingPlayer({this.audioPath});

  @override
  State<_GreetingPlayer> createState() => _GreetingPlayerState();
}

class _GreetingPlayerState extends State<_GreetingPlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    if (widget.audioPath == null || widget.audioPath!.isEmpty) return;
    final file = File(widget.audioPath!);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音文件不存在')),
        );
      }
      return;
    }
    await _player.play(DeviceFileSource(widget.audioPath!));
    if (mounted) setState(() => _isPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioPath == null || widget.audioPath!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: _togglePlay,
        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
        label: Text(_isPlaying ? '停止播放' : '播放语音祝福'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryGreen,
          side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
