import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';

/// 作品编辑器 — 播放预览、微调、保存/分享
class EditorPage extends StatefulWidget {
  final String workId;
  const EditorPage({super.key, required this.workId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  double _temperature = 0.5;  // 音乐温度
  double _speed = 1.0;        // 速度
  double _instrumentMix = 0.5; // 乐器比重
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑作品'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // TODO: 保存作品
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('作品已保存')),
              );
              context.pop();
            },
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
                      onPressed: () {
                        // TODO: 本地保存
                        context.pop();
                      },
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
