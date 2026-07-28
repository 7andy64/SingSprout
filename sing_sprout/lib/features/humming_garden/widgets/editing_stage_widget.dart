import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/instrument_mixer.dart';
import '../../../shared/widgets/speed_race_track.dart';
import '../../../shared/widgets/temperature_dial.dart';
import '../view_models/creative_flow_view_model.dart';

class EditingStageWidget extends StatelessWidget {
  final CreativeFlowViewModel vm;
  final VoidCallback onSaveLocally;
  final VoidCallback onSaveAndShare;

  const EditingStageWidget({
    super.key,
    required this.vm,
    required this.onSaveLocally,
    required this.onSaveAndShare,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = vm.generationResult != null;
    final progress = vm.playDuration > Duration.zero
        ? (vm.playPosition.inMilliseconds /
                vm.playDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    final accent = vm.styleAccentColor();

    return SingleChildScrollView(
      key: const ValueKey('editing'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Playback preview ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 132,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      accent.withValues(alpha: 0.12),
                      accent.withValues(alpha: 0.03),
                      AppTheme.bgWarm.withValues(alpha: 0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Stack(
                  children: [
                    ...List.generate(6, (i) {
                      return Positioned(
                        left: 30 + (i * 48.0) % 280,
                        top: 18 + (i * 32.0) % 80,
                        child: Opacity(
                          opacity: 0.08 + (i % 3) * 0.04,
                          child: Text(
                            ['♪', '♫', '♩', '🎵', '✨', '🎶'][i],
                            style: TextStyle(
                                fontSize: 16 + (i % 3) * 6.0,
                                color: accent),
                          ),
                        ),
                      );
                    }),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap:
                                hasResult ? vm.togglePlayPause : null,
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              width: vm.isPlaying ? 60 : 56,
                              height: vm.isPlaying ? 60 : 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: hasResult
                                      ? [
                                          const Color(0xFF6BAF4B),
                                          const Color(0xFF4A8A3B)
                                        ]
                                      : [
                                          Colors.grey.shade400,
                                          Colors.grey.shade500
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (hasResult
                                            ? AppTheme.primaryGreen
                                            : Colors.grey)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                  vm.isPlaying ? '⏸' : '▶',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasResult
                                ? '${vm.formatTime(vm.playPosition)} / ${vm.formatTime(vm.playDuration)}'
                                : '准备播放...',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                          if (hasResult &&
                              vm.playDuration > Duration.zero) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: accent
                                      .withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation(accent),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (vm.isReRendering)
                      Positioned(
                        top: 10,
                        right: 16,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // ── Editing controls ──
          TemperatureDial(
            value: vm.temperature,
            onChanged: (v) => vm.updateModulation(temperature: v),
          ),
          const SizedBox(height: 24),
          SpeedRaceTrack(
            value: vm.speed,
            onChanged: (v) => vm.updateModulation(speed: v),
          ),
          const SizedBox(height: 24),
          InstrumentMixer(
            value: vm.instrumentMix,
            onChanged: (v) => vm.updateModulation(instrumentMix: v),
          ),
          if (vm.isReRendering)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('正在调整...',
                  style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 36),
          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSaveLocally,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(26)),
                    side: const BorderSide(
                        color: AppTheme.primaryGreen),
                  ),
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSaveAndShare,
                  child: const Text('发给爸妈'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSaveAndShare,
              icon:
                  const Text('📮', style: TextStyle(fontSize: 18)),
              label: const Text(
                  '做成音乐明信片\n把这首歌寄给远方爸爸妈妈'),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(double.infinity, 56),
                side: const BorderSide(
                    color: AppTheme.primaryWarm,
                    width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(26)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

