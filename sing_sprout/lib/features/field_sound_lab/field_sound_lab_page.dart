import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 田野声音实验室 — P1 功能
class FieldSoundLabPage extends StatelessWidget {
  const FieldSoundLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('田野声音实验室'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hearing_rounded, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              '田野声音实验室',
              style: TextStyle(fontSize: 18, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              '采集身边的声音，变成音乐素材\n（下一版本开放）',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
