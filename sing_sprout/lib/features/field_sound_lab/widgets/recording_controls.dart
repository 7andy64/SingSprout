import 'package:flutter/material.dart';
import '../view_models/field_sound_lab_view_model.dart';
import 'audio_play_button.dart';

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
              if (vm.isRecording || vm.isStartingRecording)
                vm.isRecording ? _RecordingHUD(vm: vm) : _StartingIndicator()
              else if (vm.hasRecording)
                _PlaybackBar(vm: vm)
              else
                _IdleHint(vm: vm),

              // ── 录音按钮（录完后隐藏）──
              if (!vm.hasRecording) ...[
                const SizedBox(height: 20),
                _RecordButton(vm: vm, onPermissionDenied: onPermissionDenied),
              ],

              const SizedBox(height: 8),

              // ── 操作提示文字 ──
              if (vm.isRecording)
                const Text(
                  '点击完成录音',
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
                      vm.hasPermission ? '轻点开始采集' : '点击按钮开启麦克风权限',
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
      onTap: () async {
        if (vm.isRecording) {
          vm.stopRecording();
        } else {
          final error = await vm.startRecording();
          if (error == 'permission_denied') {
            onPermissionDenied?.call();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: vm.isRecording ? 110 : 96,
        height: vm.isRecording ? 110 : 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: vm.isRecording
              ? const Color(0xFFEF5350)
              : vm.hasPermission
                  ? const Color(0xFF7CB342)
                  : const Color(0xFFBDBDBD),
          boxShadow: [
            BoxShadow(
              color: (vm.isRecording
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF7CB342))
                  .withValues(alpha: 0.4),
              blurRadius: vm.isRecording ? 28 : 16,
              spreadRadius: vm.isRecording ? 4 : 0,
            ),
          ],
        ),
        child: const Text(
          '🎤',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 44,
          ),
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
          vm.hasPermission ? '轻点开始采集' : '点击按钮开启麦克风权限',
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
              // Play / Pause button (新设计)
              AudioPlayButton(
                isPlaying: vm.isPlaying,
                onTap: () {
                  if (vm.isPlaying) {
                    vm.togglePlayPause();
                  } else if (vm.playbackPosition > Duration.zero) {
                    vm.togglePlayPause();
                  } else {
                    vm.playRecording();
                  }
                },
              ),

              const SizedBox(width: 16),

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

              // 重录按钮
              GestureDetector(
                onTap: () => _confirmRerecord(context, vm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔄', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 4),
                      Text(
                        '重录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
//  重录过渡指示器（异步间隙防闪烁）
// ═══════════════════════════════════════════════

/// 重录前确认对话框 — 防止误触丢失当前录音。
Future<void> _confirmRerecord(BuildContext context, FieldSoundLabViewModel vm) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重新录制'),
      content: const Text('确定要重新录制吗？\n当前录音将被覆盖。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
          child: const Text('确定重录'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    vm.startRecording();
  }
}

class _StartingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 16),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 10),
        Text(
          '准备录音...',
          style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}
