import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/record_button.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/models/user_profile.dart';

/// 哼唱花园 — 首页 & MVP 核心创作入口
class HummingGardenPage extends StatelessWidget {
  const HummingGardenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('哼唱花园'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // 守护动物问候
            const AnimalAvatar(
              animal: GuardianAnimal.panda,
              size: 80,
              speechBubble: '嘿！今天想哼点什么？\n试试对着手机哼一句～',
            ),

            const SizedBox(height: 40),

            // 核心操作区：录音按钮
            const Spacer(),
            RecordButton(
              onRecordingStart: () {
                // TODO: 开始录音 → 跳转录音详情页
              },
              onRecordingStop: () {
                // TODO: 停止录音 → AI 分析 → 风格选择 → 生成
                context.push(AppRoutes.recording);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '长按开始哼唱',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),

            // 最近作品快速入口
            _RecentWorksSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RecentWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近作品',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 跳转作品集
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.music_note,
                      color: AppTheme.primaryGreen,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
