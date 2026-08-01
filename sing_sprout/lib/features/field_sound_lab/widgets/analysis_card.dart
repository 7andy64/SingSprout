import 'package:flutter/material.dart';
import '../view_models/field_sound_lab_view_model.dart';

/// AI 分析结果卡片 — 录音完成后滑入展示
///
/// 显示内容：
/// - 分析中状态（loading 动画）
/// - AI/模拟标签
/// - 声音类型 + BPM + 声音描述
/// - 创意推荐用途
class AnalysisCard extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  final AnimationController cardSlideController;
  final Animation<Offset> cardSlideAnimation;

  const AnalysisCard({
    super.key,
    required this.vm,
    required this.cardSlideController,
    required this.cardSlideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        if (!vm.showAnalysisCard) return const SizedBox.shrink();

        return SlideTransition(
          position: cardSlideAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with AI badge
                _TitleRow(vm: vm),

                const SizedBox(height: 14),

                // Sound type + BPM
                Row(
                  children: [
                    _TypeBadge(vm: vm),
                    const Spacer(),
                    _BpmBadge(vm: vm),
                  ],
                ),

                // Sound description (new)
                if (vm.soundDescription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🎵', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.soundDescription,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6A1B9A),
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Recommended use
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.recommendedUse,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5D4037),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleRow extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _TitleRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(vm.isAnalyzing ? '🔍' : '🤖', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          vm.isAnalyzing ? 'AI 分析中...' : 'AI 分析结果',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        if (vm.isAnalyzing) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
        const Spacer(),
        // AI / 模拟 标签
        if (!vm.isAnalyzing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: vm.isRealAi
                  ? const Color(0xFF7CB342).withValues(alpha: 0.12)
                  : const Color(0xFFFF9800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: vm.isRealAi
                    ? const Color(0xFF7CB342).withValues(alpha: 0.3)
                    : const Color(0xFFFF9800).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              vm.isRealAi ? 'AI 分析' : '智能模拟',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: vm.isRealAi
                    ? const Color(0xFF7CB342)
                    : const Color(0xFFFF9800),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _TypeBadge({required this.vm});

  @override
  Widget build(BuildContext context) {
    final color = FieldSoundLabViewModel.typeColor(vm.detectedType)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(FieldSoundLabViewModel.typeIcon(vm.detectedType),
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            vm.detectedType.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BpmBadge extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  const _BpmBadge({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 18, color: Color(0xFF42A5F5))),
          const SizedBox(width: 6),
          Text(
            '${vm.detectedBpm.toStringAsFixed(0)} BPM',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF42A5F5),
            ),
          ),
        ],
      ),
    );
  }
}
