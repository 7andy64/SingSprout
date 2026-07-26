import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/sound_sample.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/audio_service.dart';
import '../../shared/utils/formatters.dart';

class FieldSoundLabPage extends StatefulWidget {
  const FieldSoundLabPage({super.key});

  @override
  State<FieldSoundLabPage> createState() => _FieldSoundLabPageState();
}

class _FieldSoundLabPageState extends State<FieldSoundLabPage> {
  final _audioService = AudioService();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _playingId;
  Duration _recordDuration = Duration.zero;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _positionSub = _audioService.position.listen((pos) {
      if (mounted) setState(() => _playPosition = pos);
    });
    _durationSub = _audioService.duration.listen((dur) {
      if (mounted) setState(() => _playDuration = dur);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.requestMicPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要麦克风权限才能录制声音'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await _audioService.startWavRecording();
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() {
            _recordDuration = _audioService.recordingDuration ?? Duration.zero;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioService.stopRecording();
    setState(() => _isRecording = false);

    if (path == null || !mounted) return;

    final result = await _showNameDialog();
    if (result == null || !mounted) return;

    final sample = SoundSample.create(
      name: result.name,
      audioPath: path,
      type: result.type,
    );
    await context.read<AppState>().addSound(sample);
  }

  Future<({String name, SoundType type})?> _showNameDialog() async {
    final nameCtrl = TextEditingController(text: '声音 ${DateTime.now().month}/${DateTime.now().day}');
    SoundType selectedType = SoundType.unknown;

    return showDialog<({String name, SoundType type})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('保存声音'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '给这段声音起个名字',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: SoundType.values.map((type) {
                  final isSelected = type == selectedType;
                  return ChoiceChip(
                    label: Text('${_typeEmoji(type)} ${type.label}'),
                    selected: isSelected,
                    onSelected: (_) => setDialogState(() => selectedType = type),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, (name: name, type: selectedType));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlayback(SoundSample sample) {
    if (_isPlaying && _playingId == sample.id) {
      _audioService.stopPlayback();
      setState(() {
        _isPlaying = false;
        _playingId = null;
      });
    } else {
      if (_isPlaying) _audioService.stopPlayback();
      _audioService.playAudio(sample.audioPath);
      setState(() {
        _isPlaying = true;
        _playingId = sample.id;
        _playPosition = Duration.zero;
      });
    }
  }

  void _stopPlayback() {
    _audioService.stopPlayback();
    setState(() {
      _isPlaying = false;
      _playingId = null;
    });
  }

  Future<void> _deleteSound(SoundSample sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除声音'),
        content: Text('确定要删除「${sound.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (_playingId == sound.id) _stopPlayback();
      await context.read<AppState>().deleteSound(sound.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sounds = context.watch<AppState>().sounds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('田野声音实验室'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildRecorder(),
            const SizedBox(height: 16),
            if (_isRecording) _buildRecordingHint(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '已采集 ${sounds.length} 个声音',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sounds.isEmpty
                  ? _buildEmptyLibrary()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sounds.length,
                      itemBuilder: (_, i) => _SoundCard(
                        sound: sounds[i],
                        isPlaying: _isPlaying && _playingId == sounds[i].id,
                        playPosition: _playingId == sounds[i].id ? _playPosition : Duration.zero,
                        playDuration: _playingId == sounds[i].id ? _playDuration : Duration.zero,
                        onPlay: () => _togglePlayback(sounds[i]),
                        onDelete: () => _deleteSound(sounds[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecorder() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: _isRecording ? 96 : 80,
        height: _isRecording ? 96 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? AppTheme.error : AppTheme.primaryGreen,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? AppTheme.error : AppTheme.primaryGreen)
                  .withValues(alpha: 0.35),
              blurRadius: _isRecording ? 24 : 12,
              spreadRadius: _isRecording ? 6 : 0,
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildRecordingHint() {
    final secs = _recordDuration.inSeconds;
    final mins = secs ~/ 60;
    final remainSecs = secs % 60;
    final display = '${mins.toString().padLeft(2, '0')}:${remainSecs.toString().padLeft(2, '0')}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PulseDot(),
        const SizedBox(width: 8),
        Text(
          '正在录制 $display',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎤', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            '点击上方按钮开始采集',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '录制自然、动物、机械等身边的声音',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  static String _typeEmoji(SoundType type) {
    return switch (type) {
      SoundType.humanVoice => '🗣️',
      SoundType.animal => '🐾',
      SoundType.nature => '🌿',
      SoundType.mechanical => '⚙️',
      SoundType.unknown => '❓',
    };
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.error.withValues(alpha: 0.3 + _ctrl.value * 0.7),
        ),
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  final SoundSample sound;
  final bool isPlaying;
  final Duration playPosition;
  final Duration playDuration;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _SoundCard({
    required this.sound,
    required this.isPlaying,
    required this.playPosition,
    required this.playDuration,
    required this.onPlay,
    required this.onDelete,
  });

  Color get _typeColor {
    return switch (sound.type) {
      SoundType.humanVoice => const Color(0xFFFF6B6B),
      SoundType.animal => const Color(0xFFFFB347),
      SoundType.nature => AppTheme.primaryGreen,
      SoundType.mechanical => const Color(0xFF7C4DFF),
      SoundType.unknown => AppTheme.textSecondary,
    };
  }

  String get _typeEmoji {
    return switch (sound.type) {
      SoundType.humanVoice => '🗣️',
      SoundType.animal => '🐾',
      SoundType.nature => '🌿',
      SoundType.mechanical => '⚙️',
      SoundType.unknown => '❓',
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = playDuration.inMilliseconds > 0
        ? playPosition.inMilliseconds / playDuration.inMilliseconds
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(_typeEmoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sound.type.label,
                              style: TextStyle(fontSize: 11, color: _typeColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.formatDateShort(sound.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onPlay,
                  icon: Icon(
                    isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                    size: 36,
                    color: isPlaying ? AppTheme.error : AppTheme.primaryGreen,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            if (isPlaying)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text(
                      '${playPosition.inMinutes}:${(playPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          activeTrackColor: AppTheme.primaryGreen,
                          inactiveTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                    Text(
                      '${playDuration.inMinutes}:${(playDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
