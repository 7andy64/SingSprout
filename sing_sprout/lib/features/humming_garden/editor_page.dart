import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/widgets/temperature_dial.dart';
import '../../shared/widgets/speed_race_track.dart';
import '../../shared/widgets/instrument_mixer.dart';

/// 作品编辑器 — 播放预览 + 具象化微调 + 保存/分享
///
/// P1 优化：Material Slider 替换为儿童友好的具象交互组件。
class EditorPage extends StatefulWidget {
  final MusicWork work;
  const EditorPage({super.key, required this.work});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late MusicWork _work;
  final _player = AudioPlayer();
  double _temperature = 0.5;  // 音乐温度
  double _speed = 1.0;        // 速度
  double _instrumentMix = 0.5; // 乐器比重
  bool _isPlaying = false;
  bool _saving = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
    _initPlayer();
  }

  void _initPlayer() {
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    // 加载音频文件
    try {
      _player.setFilePath(_work.audioPath);
    } catch (e) {
      debugPrint('[EditorPage] 音频加载失败: $e');
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _saveWork() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // 将编辑参数写入作品的 note 字段（MVP 阶段简单序列化）
      final params =
          '温度:${_temperature.toStringAsFixed(2)}|速度:${_speed.toStringAsFixed(2)}|乐器比重:${_instrumentMix.toStringAsFixed(2)}';
      final saved = _work.copyWith(
        title: _work.title,
        note: _work.note != null ? '${_work.note}\n$params' : params,
      );
      await context.read<AppState>().addWork(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作品已保存到本地')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑作品'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _saveWork,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // 播放预览区域
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 56,
                        color: AppTheme.primaryGreen,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── 具象化编辑控件 ──
              // 每个控件自带软容器，不打硬边框

              TemperatureDial(
                value: _temperature,
                onChanged: (v) => setState(() => _temperature = v),
              ),

              const SizedBox(height: 32),

              SpeedRaceTrack(
                value: _speed,
                onChanged: (v) => setState(() => _speed = v),
              ),

              const SizedBox(height: 32),

              InstrumentMixer(
                value: _instrumentMix,
                onChanged: (v) => setState(() => _instrumentMix = v),
              ),

              const SizedBox(height: 44),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _saveWork,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        side: const BorderSide(color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 带着当前作品 ID 跳转声音邮局
                        context.push(
                          '${AppRoutes.composeCard}?workId=${_work.id}',
                        );
                      },
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('发给爸妈'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 有机云朵播放预览 — 无硬边框，渐变+阴影+音符粒子
class _OrganicPlaybackPreview extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onToggle;

  const _OrganicPlaybackPreview({
    required this.isPlaying,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 132,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              AppTheme.primaryGreen.withOpacity(0.10),
              AppTheme.primaryGreen.withOpacity(0.03),
              AppTheme.bgWarm.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 柔和的音符粒子背景
            ...List.generate(6, (i) {
              return Positioned(
                left: 30 + (i * 50.0) % 280,
                top: 20 + (i * 35.0) % 80,
                child: Opacity(
                  opacity: 0.08 + (i % 3) * 0.04,
                  child: Text(
                    ['♪', '♫', '♩', '🎵', '✨', '🎶'][i],
                    style: TextStyle(fontSize: 16 + (i % 3) * 6.0, color: AppTheme.primaryGreen),
                  ),
                ),
              );
            }),
            // 播放控制
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '00:00 / 00:30',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
