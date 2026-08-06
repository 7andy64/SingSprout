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
import '../../shared/widgets/role_gate.dart';
import '../../shared/services/role_permissions.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/economy_provider.dart';
import 'widgets/save_work_dialog.dart';

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
      if (!mounted) return;
      final work = await SaveWorkDialog.show(
        context,
        audioPath: _work.audioPath,
        styleSeed: _work.styleSeed,
        duration: _work.duration,
        defaultTitle: _work.title,
      );
      if (work == null) return; // 用户取消

      // 将编辑参数追加到 note
      final params =
          '温度:${_temperature.toStringAsFixed(2)}|速度:${_speed.toStringAsFixed(2)}|乐器比重:${_instrumentMix.toStringAsFixed(2)}';
      final saved = work.copyWith(
        note: work.note != null ? '${work.note}\n$params' : params,
      );
      await context.read<AppState>().addWork(saved);
      _onWorkCreated();
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

  /// 创作完成后触发守护动物祝贺/鼓励消息。
  void _onWorkCreated() {
    final appState = context.read<AppState>();
    final count = appState.totalWorks;
    final animal =
        appState.userProfile?.guardianAnimal ?? GuardianAnimal.panda;
    final name = animal.shortName;

    String greeting;
    if (count == 1) {
      greeting = '$name说：🎉 恭喜你创作了第一首歌！这是你音乐之旅的开始！';
    } else if (count == 5) {
      greeting = '$name说：🌟 你已经创作了 5 首歌了！越来越棒了！';
    } else if (count == 10) {
      greeting = '$name说：🏆 10 首歌达成！你是个真正的小创作家！';
    } else if (count == 20) {
      greeting = '$name说：👑 20 首歌！你太厉害了，继续加油！';
    } else {
      final encouragements = [
        '$name说：太棒了！你又创作了一首歌！',
        '$name说：真好听！继续加油哦～',
        '$name说：哇！这首歌真有感觉！',
        '$name说：你又进步了！我为你骄傲！',
      ];
      greeting = encouragements[count % encouragements.length];
    }

    appState.setPendingAnimalGreeting(greeting);
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
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
          onPressed: () => context.pop(),
        ),
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
                : const Text('✅', style: TextStyle(fontSize: 24)),
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
                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Text(
                        _isPlaying ? '⏸' : '▶',
                        style: const TextStyle(
                          fontSize: 56,
                          color: AppTheme.primaryGreen,
                        ),
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
                ownedInstrumentIds:
                    context.watch<EconomyProvider>().ownedItemIds,
              ),

              const SizedBox(height: 44),

              // 操作按钮
              Consumer<AppState>(
                builder: (context, app, _) {
                  final role = app.userProfile?.role ?? UserRole.student;
                  if (!RoleGate.isAllowed(Feature.editWork, role)) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '当前身份不支持编辑作品',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _saveWork,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            side: const BorderSide(color: AppTheme.primaryGreen),
                          ),
                          child: const Text('保存'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // 带着当前作品 ID 跳转声音邮局
                            context.push(
                              '${AppRoutes.composeCard}?workId=${_work.id}',
                            );
                          },
                          child: const Text('发给爸妈'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
