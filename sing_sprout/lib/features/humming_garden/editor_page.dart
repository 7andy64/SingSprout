import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/temperature_dial.dart';
import '../../shared/widgets/speed_race_track.dart';
import '../../shared/widgets/instrument_mixer.dart';

/// 作品编辑器 — 播放预览 + 具象化微调 + 保存/分享
///
/// P1 优化：Material Slider 替换为儿童友好的具象交互组件。
class EditorPage extends StatefulWidget {
  final String workId;
  const EditorPage({super.key, required this.workId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  double _temperature = 0.5;
  double _speed = 0.5;
  double _instrumentMix = 0.5;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑作品'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('作品已保存')),
              );
              context.pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // ── 播放预览 — 有机云朵形态 ──
              _OrganicPlaybackPreview(
                isPlaying: _isPlaying,
                onToggle: () => setState(() => _isPlaying = !_isPlaying),
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
                      onPressed: () => context.pop(),
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
                      onPressed: () => context.push(AppRoutes.composeCard),
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
