import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/mood_record.dart';
import '../../shared/services/local_storage_service.dart';
import '../../shared/widgets/mood_color_picker.dart';
import '../../shared/widgets/record_button.dart';
import '../../shared/services/audio_service.dart';
import '../../shared/providers/audio_provider.dart';

/// 心情收音机 — P1 功能（MVP 简化版）
///
/// 三种轻量入口（颜色/哼唱/文字）+ 去向选择 + 安全护栏 + 音乐心情册时间线。
/// 按优化方案 3.3.2：MVP 阶段不依赖真实 AI，用本地规则引擎生成反馈。
class MoodRadioPage extends StatefulWidget {
  const MoodRadioPage({super.key});

  @override
  State<MoodRadioPage> createState() => _MoodRadioPageState();
}

class _MoodRadioPageState extends State<MoodRadioPage> {
  static const _filename = 'mood_history.json';

  final _storage = LocalStorageService();
  final _textController = TextEditingController();

  MoodColor? _selectedMood;
  MoodEntryType _entryType = MoodEntryType.color;
  MoodDestination? _destination;
  String? _textNote;
  List<MoodRecord> _history = [];
  bool _loaded = false;
  bool _showSafetyPrompt = false;
  bool _textEntryExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await _storage.readList(_filename);
      final records = raw.map((m) => MoodRecord.fromJson(m)).toList();
      final deduped = MoodRecord.dedupeByDate(records);
      final recent = deduped.take(30).toList();

      if (!mounted) return;
      setState(() {
        _history = recent;
        _loaded = true;
        _showSafetyPrompt = MoodRecord.hasConsecutiveNegatives(recent, 7);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _selectMood(MoodColor mood) async {
    setState(() {
      _selectedMood = mood;
      _entryType = MoodEntryType.color;
      _destination = null;
      _textNote = null;
      _textEntryExpanded = false;
      _textController.clear();
    });
  }

  void _toggleTextEntry() {
    setState(() {
      _textEntryExpanded = !_textEntryExpanded;
      if (!_textEntryExpanded) _textController.clear();
    });
  }

  void _selectDestination(MoodDestination dest) {
    setState(() => _destination = dest);
  }

  Future<void> _saveMood() async {
    if (_selectedMood == null) return;

    try {
      final note = _textEntryExpanded && _textController.text.trim().isNotEmpty
          ? _textController.text.trim()
          : _textNote;

      final record = MoodRecord(
        date: DateTime.now(),
        mood: _selectedMood!,
        entryType: _textEntryExpanded ? MoodEntryType.text : _entryType,
        note: note,
        destination: _destination,
      );

      final deduped = MoodRecord.dedupeByDate([record, ..._history]);
      final recent = deduped.take(30).toList();

      setState(() {
        _history = recent;
        _selectedMood = null;
        _entryType = MoodEntryType.color;
        _destination = null;
        _textNote = null;
        _textEntryExpanded = false;
        _textController.clear();
        _showSafetyPrompt = MoodRecord.hasConsecutiveNegatives(recent, 7);
      });

      await _storage.writeList(
        _filename,
        recent.map((r) => r.toJson()).toList(),
      );
    } catch (_) {
      // Silently handle persistence errors
    }
  }

  void _dismissSafetyPrompt() {
    setState(() => _showSafetyPrompt = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情收音机'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_showSafetyPrompt) _SafetyPrompt(onDismiss: _dismissSafetyPrompt),

              const SizedBox(height: 16),

              const Text(
                '今天心情怎么样？',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '你的心情值得被听见',
                style: TextStyle(color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 32),

              MoodColorPicker(
                selected: _selectedMood,
                onSelected: _selectMood,
              ),

              if (_selectedMood != null) ...[
                const SizedBox(height: 28),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _moodToColor(_selectedMood!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedMood!.emoji} ${_selectedMood!.label}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _TextEntrySection(
                  expanded: _textEntryExpanded,
                  controller: _textController,
                  onTap: _toggleTextEntry,
                ),

                const SizedBox(height: 20),

                const Text(
                  '或者，哼一段你的心情',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                RecordButton(
                  onRecordingStart: () async {
                    setState(() => _entryType = MoodEntryType.humming);
                    // 启动真实录音，录音会持续到 RecordingPage 中停止
                    try {
                      final path = await AudioService().startRecording();
                      if (path != null && mounted) {
                        context.read<AudioProvider>().startRecording();
                      }
                    } catch (e) {
                      debugPrint('[MoodRadio] 启动录音失败: $e');
                    }
                  },
                  onRecordingStop: () {
                    // 不在此处停止录音 —— 让 RecordingPage 的"AI 生成音乐"来停
                    context.push(AppRoutes.recording);
                  },
                  size: 56,
                ),

                const SizedBox(height: 24),

                _DestinationSelector(
                  selected: _destination,
                  onSelected: _selectDestination,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveMood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _moodToColor(_selectedMood!),
                    ),
                    child: const Text('💾 记录心情'),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              const Text(
                '音乐心情册',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '最近 30 天的记录',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_loaded)
                _MoodTimeline(history: _history)
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (_loaded && _history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '还没有记录，选一个心情开始吧 ☀️',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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

// ────────────────────────────────────────────────────────────
// 安全护栏提示
// ────────────────────────────────────────────────────────────

class _SafetyPrompt extends StatelessWidget {
  final VoidCallback onDismiss;

  const _SafetyPrompt({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.moodPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.moodPurple.withOpacity(0.2),
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
                    _SafetyAction(
                      label: '好的，试试',
                      color: AppTheme.primaryGreen,
                      onTap: onDismiss,
                    ),
                    const SizedBox(width: 12),
                    _SafetyAction(
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
            child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SafetyAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SafetyAction({
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
          color: color.withOpacity(0.1),
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

// ────────────────────────────────────────────────────────────
// 文字入口区
// ────────────────────────────────────────────────────────────

class _TextEntrySection extends StatelessWidget {
  final bool expanded;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _TextEntrySection({
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

// ────────────────────────────────────────────────────────────
// 去向选择器
// ────────────────────────────────────────────────────────────

class _DestinationSelector extends StatelessWidget {
  final MoodDestination? selected;
  final ValueChanged<MoodDestination> onSelected;

  const _DestinationSelector({
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
            _DestChip(
              icon: '🌳',
              label: '仅自己',
              isSelected: selected == MoodDestination.private,
              onTap: () => onSelected(MoodDestination.private),
            ),
            const SizedBox(width: 8),
            _DestChip(
              icon: '📮',
              label: '寄给爸妈',
              isSelected: selected == MoodDestination.send,
              onTap: () => onSelected(MoodDestination.send),
            ),
            const SizedBox(width: 8),
            _DestChip(
              icon: '👥',
              label: '给老师',
              isSelected: selected == MoodDestination.teacher,
              onTap: () => onSelected(MoodDestination.teacher),
            ),
            const SizedBox(width: 8),
            _DestChip(
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

class _DestChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DestChip({
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
            color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.white,
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

// ────────────────────────────────────────────────────────────
// 音乐心情册时间线
// ────────────────────────────────────────────────────────────

class _MoodTimeline extends StatelessWidget {
  final List<MoodRecord> history;

  const _MoodTimeline({required this.history});

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
                          color: _moodToColor(r.mood).withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                      )),
                ],
              ),
            ),
            ...entry.value.map((r) => _TimelineRow(record: r)),
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

class _TimelineRow extends StatelessWidget {
  final MoodRecord record;

  const _TimelineRow({required this.record});

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
