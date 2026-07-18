import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 节奏部落 — P2 功能
class RhythmTribePage extends StatelessWidget {
  const RhythmTribePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节奏部落'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run_rounded, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              '节奏部落',
              style: TextStyle(fontSize: 18, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              '身体就是乐器，用节奏玩游戏\n（下一版本开放）',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
