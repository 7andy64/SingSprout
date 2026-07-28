import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/mood_record.dart';

// ═══ Safety prompt ═══

class SafetyPrompt extends StatelessWidget {
  final VoidCallback onDismiss;

  const SafetyPrompt({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.moodPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.moodPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎵', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '要不要把它变成一首歌？',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '音乐有时候能帮我们把心情说出来。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SafetyAction(
                      label: '好的，试试',
                      color: AppTheme.primaryGreen,
                      onTap: onDismiss,
                    ),
                    const SizedBox(width: 12),
                    SafetyAction(
                      label: '先不了',
                      color: AppTheme.textSecondary,
                      onTap: onDismiss,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Text('✕', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class SafetyAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SafetyAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }
}

// ═══ Text entry section ═══

class TextEntrySection extends StatelessWidget {
  final bool expanded;
  final TextEditingController controller;
  final VoidCallback onTap;

  const TextEntrySection({
    super.key,
    required this.expanded,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded ? AppTheme.primaryGreen : AppTheme.divider,
            width: expanded ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✍️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text(
                  '写下来',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  expanded ? '收起' : '展开',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (!expanded)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 26),
                child: Text(
                  '想说的话（给爸妈 / 给自己 / 给树洞）',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            if (expanded) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: '今天想说什么心里话…',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  border: OutlineInputBorder(),
                  counterStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══ Destination selector ═══

class DestinationSelector extends StatelessWidget {
  final MoodDestination? selected;
  final ValueChanged<MoodDestination> onSelected;

  const DestinationSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '给谁看？',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            DestChip(
              icon: '🌳',
              label: '仅自己',
              isSelected: selected == MoodDestination.private,
              onTap: () => onSelected(MoodDestination.private),
            ),
            const SizedBox(width: 8),
            DestChip(
              icon: '📮',
              label: '寄给爸妈',
              isSelected: selected == MoodDestination.send,
              onTap: () => onSelected(MoodDestination.send),
            ),
            const SizedBox(width: 8),
            DestChip(
              icon: '👥',
              label: '给老师',
              isSelected: selected == MoodDestination.teacher,
              onTap: () => onSelected(MoodDestination.teacher),
            ),
            const SizedBox(width: 8),
            DestChip(
              icon: '🗑️',
              label: '不保存',
              isSelected: selected == MoodDestination.discard,
              onTap: () => onSelected(MoodDestination.discard),
            ),
          ],
        ),
      ],
    );
  }
}

class DestChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DestChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══ Mood timeline ═══

class MoodTimeline extends StatelessWidget {
  final List<MoodRecord> history;

  const MoodTimeline({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MoodRecord>>{};
    for (final r in history) {
      final monthKey = '${r.date.year}年${r.date.month}月';
      grouped.putIfAbsent(monthKey, () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...entry.value.take(5).map((r) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _moodToColor(r.mood).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      )),
                ],
              ),
            ),
            ...entry.value.map((r) => TimelineRow(record: r)),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
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
}

class TimelineRow extends StatelessWidget {
  final MoodRecord record;

  const TimelineRow({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final color = _moodToColor(record.mood);
    final dayLabel =
        '${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')}';
    final entryIcon = _entryTypeIcon(record.entryType);

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              dayLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${record.mood.emoji} ${record.mood.label}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(entryIcon, style: const TextStyle(fontSize: 12)),
          if (record.note != null && record.note!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                record.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _entryTypeIcon(MoodEntryType type) {
    switch (type) {
      case MoodEntryType.color:
        return '🎨';
      case MoodEntryType.humming:
        return '🎤';
      case MoodEntryType.text:
        return '✍️';
    }
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
}
