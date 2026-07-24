import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';

/// 作品编辑器 — 播放预览、微调、保存/分享
class EditorPage extends StatefulWidget {
  final MusicWork work;
  const EditorPage({super.key, required this.work});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late MusicWork _work;
  double _temperature = 0.5;  // 音乐温度
  double _speed = 1.0;        // 速度
  double _instrumentMix = 0.5; // 乐器比重
  bool _isPlaying = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _work = widget.work;
  }

  Future<void> _saveWork() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // 将编辑参数写入作品的 note 字段（MVP 阶段简单序列化）
      final params =
          '温度:${_temperature.toStringAsFixed(2)}|速度:${_speed.toStringAsFixed(2)}|乐器比重:${_instrumentMix.toStringAsFixed(2)}';
      final saved = _work.copyWith(
        title: _work.title,
        note: _work.note != null ? '${_work.note}\n$params' : params,
      );
      await context.read<AppState>().addWork(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作品已保存到本地')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑作品'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _saveWork,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 播放预览区域
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 56,
                        color: AppTheme.primaryGreen,
                      ),
                      onPressed: () {
                        setState(() => _isPlaying = !_isPlaying);
                        // TODO: 播放/暂停音频
                      },
                    ),
                    const Text(
                      '00:00 / 00:30',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 音乐温度调节
              _SliderControl(
                label: '🎵 音乐温度',
                leftLabel: '柔和',
                rightLabel: '热烈',
                value: _temperature,
                onChanged: (v) => setState(() => _temperature = v),
              ),

              const SizedBox(height: 20),

              // 速度调节
              _SliderControl(
                label: '⏱ 速度',
                leftLabel: '慢',
                rightLabel: '快',
                value: _speed,
                onChanged: (v) => setState(() => _speed = v),
              ),

              const SizedBox(height: 20),

              // 乐器比重
              _SliderControl(
                label: '🎹 乐器比重',
                leftLabel: '纯人声',
                rightLabel: '丰富配器',
                value: _instrumentMix,
                onChanged: (v) => setState(() => _instrumentMix = v),
              ),

              const Spacer(),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _saveWork,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: 跳转声音邮局
                        context.push(AppRoutes.composeCard);
                      },
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('发给爸妈'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderControl extends StatelessWidget {
  final String label;
  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        Row(
          children: [
            Text(leftLabel,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            Expanded(
              child: Slider(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primaryGreen,
              ),
            ),
            Text(rightLabel,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}
