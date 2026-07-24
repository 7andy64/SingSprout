import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/mood_record.dart';
import '../../shared/services/local_storage_service.dart';
import '../../shared/widgets/mood_color_picker.dart';
import '../../shared/widgets/record_button.dart';

/// 心情收音机 — P1 功能，孩子主动选择心情，不做 AI 判断
class MoodRadioPage extends StatefulWidget {
  const MoodRadioPage({super.key});

  @override
  State<MoodRadioPage> createState() => _MoodRadioPageState();
}

class _MoodRadioPageState extends State<MoodRadioPage> {
  static const _filename = 'mood_history.json';

  final _storage = LocalStorageService();
  MoodColor? _selectedMood;
  List<MoodRecord> _history = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final raw = await _storage.readList(_filename);
    final records = raw.map((m) => MoodRecord.fromJson(m)).toList();
    final deduped = MoodRecord.dedupeByDate(records);
    // 仅保留最近 7 天
    final recent = deduped.take(7).toList();
    if (!mounted) return;
    setState(() {
      _history = recent;
      _loaded = true;
    });
  }

  Future<void> _selectMood(MoodColor mood) async {
    final record = MoodRecord(date: DateTime.now(), mood: mood);
    final deduped = MoodRecord.dedupeByDate([record, ..._history]);
    final recent = deduped.take(7).toList();

    setState(() {
      _selectedMood = mood;
      _history = recent;
    });

    // 异步持久化
    await _storage.writeList(
      _filename,
      recent.map((r) => r.toJson()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情收音机'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
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
                '选择一个颜色告诉我吧',
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
                    color: AppTheme.moodToColor(_selectedMood!).withOpacity(0.1),
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
                const Text(
                  '想不想哼唱出来？',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),

                const SizedBox(height: 24),
                RecordButton(
                  onRecordingStart: () {},
                  onRecordingStop: () {
                    context.push(AppRoutes.recording);
                  },
                  size: 64,
                ),
              ],

              const Spacer(),

              // 心情历史色卡
              const Text(
                '最近的心情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_loaded)
                _MoodHistoryRow(history: _history)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    7,
                    (i) => Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

}

/// 最近 7 天心情历史色卡
class _MoodHistoryRow extends StatelessWidget {
  final List<MoodRecord> history;

  const _MoodHistoryRow({required this.history});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        // history 已按日期降序排列
        final record = i < history.length ? history[i] : null;
        final color = record != null ? AppTheme.moodToColor(record.mood) : AppTheme.divider;
        final emoji = record?.mood.emoji ?? '';

        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(record != null ? 1 : 0.3),
            shape: BoxShape.circle,
          ),
          child: record != null
              ? Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                )
              : null,
        );
      }),
    );
  }
}
