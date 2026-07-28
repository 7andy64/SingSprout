import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/music_work.dart';
import 'mood_tree_painter.dart';

class PreviewSheet extends StatefulWidget {
  final MusicWork work;
  const PreviewSheet({super.key, required this.work});

  @override
  State<PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<PreviewSheet>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late AnimationController _swayCtrl;
  StreamSubscription? _posSub, _durSub, _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _swayCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1));
    _stateSub = _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
      if (s.playing) {
        _swayCtrl.repeat(reverse: true);
      } else {
        _swayCtrl.stop();
        _swayCtrl.value = 0;
      }
    });
    _posSub = _player.positionStream
        .listen((p) { if (mounted) setState(() => _pos = p); });
    _durSub = _player.durationStream.listen((d) {
      if (mounted) setState(() => _dur = d ?? Duration.zero);
    });
    _initPlay();
  }

  Future<void> _initPlay() async {
    try {
      await _player.setFilePath(widget.work.audioPath);
      if (mounted) await _player.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    _swayCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _swayCtrl,
            builder: (_, child) => Transform.rotate(
                angle: _swayCtrl.value * 0.08 - 0.04,
                child: child),
            child: CustomPaint(
              size: const Size(80, 80),
              painter:
                  MoodTreePainter(widget.work.moodSticker),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.work.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(children: [
            Text(_fmt(_pos),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary)),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                    trackHeight: 3,
                    thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 8)),
                child: Slider(
                  value: _dur.inMilliseconds > 0
                      ? _pos.inMilliseconds
                          .clamp(0, _dur.inMilliseconds)
                          .toDouble()
                      : 0,
                  max: _dur.inMilliseconds > 0
                      ? _dur.inMilliseconds.toDouble()
                      : 1,
                  onChanged: (v) => _player.seek(
                      Duration(milliseconds: v.toInt())),
                  activeColor: AppTheme.primaryGreen,
                ),
              ),
            ),
            Text(_fmt(_dur),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                _isPlaying ? _player.pause() : _player.play(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [
                  Color(0xFF6BAF4B),
                  Color(0xFF4A8A3B)
                ]),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryGreen
                          .withValues(alpha: 0.3),
                      blurRadius: 12)
                ],
              ),
              child: Center(
                  child: Icon(
                      _isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 28)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                    '${AppRoutes.composeCard}?workId=${widget.work.id}');
              },
              icon: const Text('📮'),
              label: const Text('做成明信片'),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppTheme.primaryWarm,
                      width: 1.5)),
            ),
          ),
        ]),
      ),
    );
  }
}
