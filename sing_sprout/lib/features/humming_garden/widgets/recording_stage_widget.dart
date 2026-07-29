import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/app_state.dart';
import '../../../shared/widgets/animal_avatar.dart';
import '../view_models/creative_flow_view_model.dart';

/// Idle stage — "tap to record" prompt with panda mascot.
class IdleStageWidget extends StatelessWidget {
  final CreativeFlowViewModel vm;
  final AnimationController breatheController;
  final AnimationController pressScaleController;
  final AnimationController transitionController;
  final bool isLongPressing;
  final VoidCallback onGoToRecording;
  final void Function(bool isInside) onFingerInsideChanged;

  const IdleStageWidget({
    super.key,
    required this.vm,
    required this.breatheController,
    required this.pressScaleController,
    required this.transitionController,
    required this.isLongPressing,
    required this.onGoToRecording,
    required this.onFingerInsideChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transitionController,
      builder: (context, child) {
        final t = isLongPressing
            ? Curves.easeOut.transform((pressScaleController.value * 0.4).clamp(0.0, 0.4) / 0.4)
            : Curves.easeIn.transform((1.0 - transitionController.value).clamp(0.0, 1.0));
        return Column(
          key: const ValueKey('idle'),
          children: [
            const SizedBox(height: 25),
            const Text('声芽',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF639960),
                    letterSpacing: 4)),
            const SizedBox(height: 12),
            const Text('用声音种一棵音乐树',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF888888),
                    letterSpacing: 1)),
            const SizedBox(height: 60),
            Opacity(
              opacity: 1.0 - t * 0.6,
              child: Transform.translate(
                offset: Offset(0, -t * 20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: const Text(
                    '轻轻按住麦克风哼一段小调，你的声音会长出专属音乐小树，还能做成明信片送给家人',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF444444),
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 35),
            Opacity(
              opacity: 1.0 - t * 0.4,
              child: Transform.translate(
                offset: Offset(0, -t * 30),
                child: AnimatedBuilder(
                  animation: breatheController,
                  builder: (context, child) => Transform.scale(
                    scale: 1.0 + breatheController.value * 0.03,
                    child: child,
                  ),
                  child: Consumer<AppState>(
                    builder: (_, app, __) => AnimalAvatar(
                        animal: app.userProfile?.guardianAnimal ??
                            GuardianAnimal.panda,
                        size: 80,
                        speechBubble: null),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            Transform.scale(
              scale: 1.0 + t * 0.3,
              child: GestureDetector(
                onTap: () => onGoToRecording(),
                onLongPressStart: (_) => onGoToRecording(),
                onLongPressMoveUpdate: (details) {
                  final isInside = details.localPosition.dy > -60;
                  onFingerInsideChanged(isInside);
                },
                child: AnimatedBuilder(
                  animation: pressScaleController,
                  builder: (context, child) => Transform.scale(
                    scale: isLongPressing
                        ? 1.0 + pressScaleController.value * 0.12
                        : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isLongPressing
                              ? const Color(0xFF6BAF4B)
                                  .withValues(alpha: 0.55)
                              : const Color(0xFF6BAF4B)
                                  .withValues(alpha: 0.3),
                          blurRadius: isLongPressing ? 28 : 16,
                          spreadRadius: isLongPressing ? 8 : 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎤',
                        style: TextStyle(
                            color: Colors.white, fontSize: 36)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('轻点开始录音',
                style:
                    TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text('多录制几段旋律，花园页面就能长满小树啦',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFAAAAAA))),
            ),
          ],
        );
      },
    );
  }
}
