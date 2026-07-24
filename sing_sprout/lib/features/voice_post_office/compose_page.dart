import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// 撰写音乐明信片 — 选择作品 + 写一句话 → 生成卡片 → 微信分享
class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  String _message = '';
  String? _selectedWorkId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('写音乐明信片'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择音乐作品
              const Text(
                '选择一首作品',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Center(
                  child: Text(
                    '从哼唱花园选择一首作品',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 写给谁
              const Text(
                '想说的话',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLength: 100,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '比如：妈妈我好想你...',
                ),
                onChanged: (v) => _message = v,
              ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '预览: ${_message.length > 30 ? '${_message.substring(0, 30)}...' : _message}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),

              const Spacer(),

              // 预览与发送
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final hasWork = _selectedWorkId != null;
                    // TODO: AI 生成封面 → 生成微信分享卡片
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(hasWork
                            ? '明信片已生成，已复制分享链接'
                            : '请先选择一首作品再发送'),
                      ),
                    );
                    context.pop();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('生成明信片并分享'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '将通过微信发送给爸爸妈妈',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withOpacity(0.7),
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
