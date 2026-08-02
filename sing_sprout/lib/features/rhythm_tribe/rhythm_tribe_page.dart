import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/economy_provider.dart';

/// 节奏部落 — 音乐游戏大厅
///
/// 三个游戏入口 + 每日挑战 + 金松果余额展示。
/// 设计原则：大卡片、emoji 图标、即时反馈、低认知负荷。
class RhythmTribePage extends StatelessWidget {
  const RhythmTribePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节奏部落'),
        centerTitle: true,
      ),
      body: Consumer<EconomyProvider>(
        builder: (context, economy, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 金松果余额
              _CoinCard(economy: economy),
              const SizedBox(height: 20),

              // 每日挑战
              _DailyChallengeCard(economy: economy),
              const SizedBox(height: 20),

              // 游戏入口
              const Text('音乐游戏',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),

              _GameEntryCard(
                emoji: '🥁',
                title: '节奏游戏',
                subtitle: '跟着节拍点击，比比谁更准',
                reward: '每局最高 +10 🌰',
                color: const Color(0xFFFF6B6B),
                onTap: () => context.push('/rhythm-game'),
              ),
              const SizedBox(height: 10),

              _GameEntryCard(
                emoji: '🎤',
                title: '旋律闯关',
                subtitle: '听一段旋律，哼唱模仿',
                reward: '音高越准，奖励越多',
                color: const Color(0xFF4D96FF),
                onTap: () => context.push('/melody-challenge'),
              ),
              const SizedBox(height: 10),

              _GameEntryCard(
                emoji: '🎧',
                title: '声音收集图鉴',
                subtitle: '在田野里发现各种声音',
                reward: '每发现新声音 +3 🌰',
                color: const Color(0xFF6BCB77),
                onTap: () => context.push('/sound-collection'),
              ),
              const SizedBox(height: 32),

              // 金松果说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🌰 金松果是什么？',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    SizedBox(height: 8),
                    Text(
                      '金松果是你在音乐世界里获得的奖励。\n'
                      '玩游戏、发现声音、完成每日挑战都能获得。\n'
                      '拿到金松果后，可以去森林集市兑换头像框、小动物皮肤、音乐树挂饰等好东西！\n\n'
                      '每天最多获得 100 颗金松果，小松果们也需要休息哦。',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 金松果余额卡片
class _CoinCard extends StatelessWidget {
  final EconomyProvider economy;

  const _CoinCard({required this.economy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5D04A), Color(0xFFF0A500)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5D04A).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🌰', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${economy.balance} 颗金松果',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  economy.isDailyLimitReached
                      ? '今天的小松果们已经睡觉啦'
                      : '今日还能获得 ${economy.remainingToday} 颗',
                  style: const TextStyle(fontSize: 13, color: AppTheme.primarySoil),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/shop'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primarySoil),
            child: const Text('去集市 🛍️'),
          ),
        ],
      ),
    );
  }
}

/// 每日挑战卡片
class _DailyChallengeCard extends StatelessWidget {
  final EconomyProvider economy;

  const _DailyChallengeCard({required this.economy});

  @override
  Widget build(BuildContext context) {
    final done = economy.dailyChallengeCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: done ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? AppTheme.primaryGreen : AppTheme.primaryWarm,
          width: done ? 1.5 : 2,
        ),
      ),
      child: Row(
        children: [
          Text(done ? '✅' : '🎯', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? '今日挑战已完成' : '每日挑战',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  done ? '太棒了！明天再来吧' : '完成一次旋律闯关，获得额外金松果奖励',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (done)
            const Text('+6 🌰', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen))
          else
            FilledButton(
              onPressed: () => context.push('/melody-challenge'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 36),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('去完成'),
            ),
        ],
      ),
    );
  }
}

/// 游戏入口卡片
class _GameEntryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String reward;
  final Color color;
  final VoidCallback onTap;

  const _GameEntryCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(reward, style: const TextStyle(fontSize: 12, color: AppTheme.primarySoil)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
