import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _SoundsPageState extends State<SoundsPage> {
  final _audioService = AudioService();
  String? _playingId;
  bool _isPlaying = false;
  Duration _playPos = Duration.zero;
  Duration _playDur = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    _posSub = _audioService.position.listen((pos) {
      if (mounted) setState(() => _playPos = pos);
    });
    _durSub = _audioService.duration.listen((dur) {
      if (mounted) setState(() => _playDur = dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _audioService.stopPlayback();
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
        _playPos = Duration.zero;
      });
    }
  }

  Future<void> _stopPlayback() async {
    await _audioService.stopPlayback();
    setState(() {
      _playingId = null;
      _isPlaying = false;
      _playPos = Duration.zero;
    });
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
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: sounds.length,
                  itemBuilder: (_, i) => _SoundCard(
                    sound: sounds[i],
                    isPlaying: _playingId == sounds[i].id && _isPlaying,
                    isActive: _playingId == sounds[i].id,
                    playPos: _playingId == sounds[i].id ? _playPos : Duration.zero,
                    playDur: _playingId == sounds[i].id ? _playDur : Duration.zero,
                    onPlay: () => _togglePlay(sounds[i]),
                    onDelete: () => _confirmDelete(context, sounds[i]),
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

  void _confirmDelete(BuildContext context, SoundSample sound) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除声音'),
        content: Text('确定要删除「${sound.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (_playingId == sound.id) await _stopPlayback();
              await context.read<AppState>().deleteSound(sound.id);
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

/// 声音样本卡片 — 支持点击播放/暂停
class _SoundCard extends StatelessWidget {
  final SoundSample sound;
  final bool isPlaying;
  final bool isActive;
  final Duration playPos;
  final Duration playDur;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _SoundCard({
    required this.sound,
    required this.isPlaying,
    required this.isActive,
    required this.playPos,
    required this.playDur,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = playDur.inMilliseconds > 0
        ? playPos.inMilliseconds / playDur.inMilliseconds
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 左侧类型图标 + 播放状态
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _typeColor(sound.type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isPlaying
                            ? const Icon(Icons.pause,
                                size: 28, color: AppTheme.primaryGreen)
                            : isActive
                                ? const Icon(Icons.play_arrow,
                                    size: 28, color: AppTheme.primaryGreen)
                                : Text(
                                    _typeEmoji(sound.type),
                                    style: const TextStyle(fontSize: 26),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 信息区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sound.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _typeColor(sound.type)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sound.type.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _typeColor(sound.type),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (sound.bpm != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'BPM ${sound.bpm!.round()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatDateShort(sound.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 删除按钮
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              // 播放进度条（仅在播放或暂停时显示）
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Text(
                        _fmtDuration(playPos),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                AppTheme.primaryGreen.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                              isPlaying
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary,
                            ),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtDuration(playDur),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
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
