import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';

/// 声音邮局 — MVP P0 功能：亲子通信
class PostOfficePage extends StatelessWidget {
  const PostOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('声音邮局'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 写新明信片入口
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.composeCard),
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  label: const Text('写一张音乐明信片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryWarm,
                    foregroundColor: AppTheme.textPrimary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tab 切换：收件箱 / 发件箱
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: AppTheme.primaryGreen,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryGreen,
                      tabs: [
                        Tab(text: '收件箱'),
                        Tab(text: '发件箱'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _InboxTab(),
                          _OutboxTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _EmptyState(
          icon: Icons.mail_outline_rounded,
          message: '还没有收到回信\n试试给爸妈发第一张明信片吧',
        ),
      ],
    );
  }
}

class _OutboxTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _EmptyState(
          icon: Icons.send_outlined,
          message: '还没有发送过明信片\n创作一首歌然后发给爸妈',
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
