import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/enums.dart';
import '../../../shared/models/music_work.dart';

/// 作品保存弹窗 — 心情贴纸 + 备注 + 私密标记
class SaveWorkDialog extends StatefulWidget {
  final String audioPath;
  final StyleSeed styleSeed;
  final Duration duration;
  final String defaultTitle;

  const SaveWorkDialog({
    super.key,
    required this.audioPath,
    required this.styleSeed,
    required this.duration,
    this.defaultTitle = '我的哼唱',
  });

  /// 弹出保存对话框，返回构造好的 MusicWork（或 null 表示取消）
  static Future<MusicWork?> show(
    BuildContext context, {
    required String audioPath,
    required StyleSeed styleSeed,
    required Duration duration,
    String defaultTitle = '我的哼唱',
  }) {
    return showDialog<MusicWork>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveWorkDialog(
        audioPath: audioPath,
        styleSeed: styleSeed,
        duration: duration,
        defaultTitle: defaultTitle,
      ),
    );
  }

  @override
  State<SaveWorkDialog> createState() => _SaveWorkDialogState();
}

class _SaveWorkDialogState extends State<SaveWorkDialog> {
  MoodColor? _selectedMood;
  final _noteController = TextEditingController();
  bool _isPrivate = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _moodToColor(MoodColor mood) {
    switch (mood) {
      case MoodColor.red:
        return AppTheme.moodRed;
      case MoodColor.yellow:
        return AppTheme.moodYellow;
      case MoodColor.green:
        return AppTheme.moodGreen;
      case MoodColor.blue:
        return AppTheme.moodBlue;
      case MoodColor.purple:
        return AppTheme.moodPurple;
      case MoodColor.grey:
        return AppTheme.moodGrey;
    }
  }

  void _save() {
    final work = MusicWork.create(
      title: widget.defaultTitle,
      audioPath: widget.audioPath,
      styleSeed: widget.styleSeed,
      moodSticker: _selectedMood,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      duration: widget.duration,
    );

    // 应用私密标记
    final result = work.copyWith(
      isPrivate: _isPrivate,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(24, 40, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                const Row(children: [
                  Text('🎵', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text('保存你的作品',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                // 心情贴纸
                const Text('贴上心情贴纸',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: MoodColor.values.map((mood) {
                    final isSelected = mood == _selectedMood;
                    final color = _moodToColor(mood);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMood = mood),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(isSelected ? 1 : 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: isSelected ? 3 : 0),
                          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)] : null,
                        ),
                        child: Center(child: Text(mood.emoji, style: const TextStyle(fontSize: 20))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // 短句备注
                const Text('写一句此刻的心情',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: TextField(
                    controller: _noteController,
                    maxLength: 50,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: '比如：今天好开心呀～',
                      isDense: true,
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.primaryGreen.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                      counterStyle: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 私密标记
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.moodGrey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    value: _isPrivate,
                    onChanged: (v) => setState(() => _isPrivate = v ?? false),
                    title: const Text('🔒 私密标记', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('加密保存，不会上传到云端', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 12),
                // 按钮行
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppTheme.textSecondary),
                        ),
                        child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
