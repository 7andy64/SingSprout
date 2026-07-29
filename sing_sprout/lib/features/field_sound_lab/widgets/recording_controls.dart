import 'package:flutter/material.dart';
import '../view_models/field_sound_lab_view_model.dart';

/// 录音控制区 — 录音按钮 + 状态 HUD + 回放控制
class RecordingControls extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  final VoidCallback? onPermissionDenied;

  const RecordingControls({
    super.key,
    required this.vm,
    this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              // ── 录音中 HUD / 空闲提示 ──
              if (vm.isRecording)
                _RecordingHUD(vm: vm)
              else if (vm.hasRecording)
                _PlaybackBar(vm: vm)
              else
                _IdleHint(vm: vm),

              const SizedBox(height: 20),

              // ── 录音按钮（录制中变大 + 红色光晕）──
              _RecordButton(vm: vm, onPermissionDenied: onPermissionDenied),

              const SizedBox(height: 8),

              // ── 操作提示文字 ──
              if (vm.isRecording)
                const Text(
                  '松开停止录音',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (!vm.hasRecording)
                Column(
                  children: [
                    Text(
                      vm.hasPermission ? '长按按钮开始采集' : '点击按钮开启麦克风权限',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '最长 30 秒',
                      style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
//  Record Button
// ═══════════════════════════════════════════════

class _RecordButton extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  final VoidCallback? onPermissionDenied;
  const _RecordButton({required this.vm, this.onPermissionDenied});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) async {
        if (!vm.isRecording && !vm.hasRecording) {
          final error = await vm.startRecording();
          if (error == 'permission_denied') {
            onPermissionDenied?.call();
          }
        }
      },
      onLongPressEnd: (_) {
        if (vm.isRecording) vm.stopRecording();
      },
      onLongPressCancel: () {
        if (vm.isRecording) vm.stopRecording();
      },
      onTap: vm.hasRecording
          ? null // 有录音时，长按被禁用，只能用回放区的按钮
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: vm.isRecording ? 110 : 96,
        height: vm.isRecording ? 110 : 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: vm.isRecording
              ? const Color(0xFFEF5350)
              : vm.hasRecording
                  ? const Color(0xFF42A5F5)
                  : vm.hasPermission
                      ? const Color(0xFF7CB342)
                      : const Color(0xFFBDBDBD),
          boxShadow: [
            BoxShadow(
              color: (vm.isRecording
                      ? const Color(0xFFEF5350)
                      : vm.hasRecording
                          ? const Color(0xFF42A5F5)
                          : const Color(0xFF7CB342))
                  .withValues(alpha: 0.4),
              blurRadius: vm.isRecording ? 28 : 16,
              spreadRadius: vm.isRecording ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          vm.isRecording
              ? Icons.mic
              : vm.hasRecording
                  ? Icons.check_circle
                  : Icons.mic_none,
          color: Colors.white,
          size: 44,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Idle Hint
// ═══════════════════════════════════════════════

class _IdleHint extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _IdleHint({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          '🎤 发现身边的声音',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vm.hasPermission ? '长按按钮开始采集' : '点击按钮开启麦克风权限',
          style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  Recording HUD（倒计时 + 音量指示 + 进度条）
// ═══════════════════════════════════════════════

class _RecordingHUD extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _RecordingHUD({required this.vm});

  @override
  Widget build(BuildContext context) {
    final progress = vm.recordProgress;
    final barColor = vm.recordSecondsRemaining <= 5
        ? const Color(0xFFEF5350)
        : const Color(0xFF7CB342);
    final remainingStr =
        '00:${vm.recordSecondsRemaining.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Volume dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(10, (i) {
            final active = vm.currentAmplitude > i * 0.1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: active ? 20.0 + vm.currentAmplitude * 16 : 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: active
                    ? barColor
                        .withValues(alpha: 0.4 + vm.currentAmplitude * 0.6)
                    : const Color(0xFFE0E0E0),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        // Countdown timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            remainingStr,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: barColor,
              fontFamily: 'monospace',
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Progress bar
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  Playback Bar（录音完成后、保存前的试听）
// ═══════════════════════════════════════════════

class _PlaybackBar extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _PlaybackBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final posStr = _formatDuration(vm.playbackPosition);
    final durStr = _formatDuration(vm.playbackDuration);

    return Column(
      children: [
        const Text(
          '✅ 录音完成',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '可以试听或重新录制',
          style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 12),

        // ── Playback controls ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / Pause
              _PlayPauseButton(vm: vm),

              const SizedBox(width: 12),

              // Progress bar + time
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: vm.playbackProgress,
                        backgroundColor:
                            const Color(0xFF42A5F5).withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF42A5F5)),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(posStr,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF999999))),
                        Text(durStr,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF999999))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Re-record
              GestureDetector(
                onTap: () => vm.startRecording(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh,
                      size: 20, color: Color(0xFFFF9800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

// ═══════════════════════════════════════════════
//  Play / Pause Button
// ═══════════════════════════════════════════════

class _PlayPauseButton extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _PlayPauseButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (vm.hasRecording) {
          if (vm.isPlaying) {
            vm.stopPlayback();
          } else if (vm.playbackPosition > Duration.zero) {
            vm.togglePlayPause();
          } else {
            vm.playRecording();
          }
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF42A5F5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          vm.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
