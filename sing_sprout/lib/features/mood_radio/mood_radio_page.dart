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
import 'widgets/mood_radio_widgets.dart';

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
    // 保存后进入创作界面
    if (mounted) context.push(AppRoutes.creativeFlow);
  }

  void _dismissSafetyPrompt() {
    setState(() => _showSafetyPrompt = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: const Text('心情收音机'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showSafetyPrompt) SafetyPrompt(onDismiss: _dismissSafetyPrompt),

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
                    color: _moodToColor(_selectedMood!).withValues(alpha: 0.1),
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

                TextEntrySection(
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

                DestinationSelector(
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
                MoodTimeline(history: _history)
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
