import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';

/// 守护动物场景气泡 — 根据 AppState 显示上下文提示语
class GuardianSceneBubble extends StatelessWidget {
  final AppState appState;

  const GuardianSceneBubble({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final (tip, icon) = _resolveTip();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, IconData) _resolveTip() {
    if (appState.totalSounds == 0) {
      return ('去采集一个声音吧！', Icons.mic_external_on_rounded);
    }
    if (appState.totalWorks == 0) {
      return ('创作你的第一首歌吧！', Icons.music_note_rounded);
    }
    if (appState.animalState == AnimalState.expecting) {
      return ('有人给你回信啦，快去看看吧！', Icons.mail_rounded);
    }
    if (appState.animalState == AnimalState.miss) {
      return ('好久不见，我想你了...', Icons.sentiment_dissatisfied_rounded);
    }
    return ('嘿！今天想做什么？', Icons.waving_hand_rounded);
  }
}
