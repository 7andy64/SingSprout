import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/seed_growth_painter.dart';
import '../view_models/creative_flow_view_model.dart';

class GeneratingStageWidget extends StatelessWidget {
  final CreativeFlowViewModel vm;
  final AnimationController growthController;
  final VoidCallback onSkipToEditing;

  static const _stageRows = [
    (icon: '🎤', label: '录制完成'),
    (icon: '🔍', label: '在旋律中寻找音符'),
    (icon: '🎵', label: '识别出你的旋律'),
    (icon: '🎹', label: '编织和弦伴奏'),
    (icon: '✨', label: '生成完整音乐'),
  ];

  const GeneratingStageWidget({
    super.key,
    required this.vm,
    required this.growthController,
    required this.onSkipToEditing,
  });

  @override
  Widget build(BuildContext context) {
    final progress = vm.pipelineProgress;
    final currentIdx = vm.completedStageIndex;
    final allDone = progress != null && progress.fraction >= 1.0;
    final accent = vm.styleAccentColor();

    return SingleChildScrollView(
      key: const ValueKey('generating'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: growthController,
              builder: (context, _) => CustomPaint(
                painter: SeedGrowthPainter(
                  progress: growthController.value,
                  accentColor: accent,
                ),
                size: const Size(double.infinity, 100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              allDone
                  ? '你的音乐发芽了！'
                  : (progress?.stageName ?? '准备中...'),
              key: ValueKey(progress?.stageName ?? 'prep'),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          if (progress?.detail != null) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                progress!.detail!,
                key: ValueKey(progress.detail),
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              color: accent.withValues(alpha: 0.1),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress?.fraction ?? 0.02,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(colors: [
                      accent,
                      accent.withGreen(
                          (accent.g + 40).clamp(0, 255).toInt())
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_stageRows.length, (i) {
            final isCompleted = i <= currentIdx;
            final isCurrent = i == currentIdx + 1;
            final row = _stageRows[i];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isCompleted
                    ? accent.withValues(alpha: 0.08)
                    : isCurrent
                        ? accent.withValues(alpha: 0.04)
                        : Colors.transparent,
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: SizedBox(
                      key: ValueKey('stage_${i}_$isCompleted'),
                      width: 36,
                      height: 36,
                      child: isCompleted
                          ? Icon(Icons.check_circle_rounded,
                              color: accent, size: 28)
                          : isCurrent
                              ? _PulseIconWidget(
                                  icon: row.icon, color: accent)
                              : Opacity(
                                  opacity: 0.3,
                                  child: Text(row.icon,
                                      style: const TextStyle(
                                          fontSize: 22)),
                                ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCompleted || isCurrent
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          if (allDone)
            ElevatedButton(
              onPressed: onSkipToEditing,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('🎧 听听看'),
            ),
          const SizedBox(height: 16),
          if (!allDone && currentIdx >= 1)
            TextButton(
              onPressed: vm.isGenerating ? null : onSkipToEditing,
              child: const Text('好啦，让我看看',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Pulsing icon for the currently-active stage row.
class _PulseIconWidget extends StatefulWidget {
  final String icon;
  final Color color;
  const _PulseIconWidget({required this.icon, required this.color});

  @override
  State<_PulseIconWidget> createState() => _PulseIconWidgetState();
}

class _PulseIconWidgetState extends State<_PulseIconWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Text(widget.icon, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
