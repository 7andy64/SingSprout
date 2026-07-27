import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/models/music_tree_data.dart';
import '../../../shared/services/music_tree_service.dart';
import '../../../shared/widgets/tree_visual.dart';

/// 极简音乐树摘要卡片 — 首页底部入口
/// 仅展示本周创作数和连续活跃天数，无排行榜、无攀比
class MusicTreeSummary extends StatelessWidget {
  const MusicTreeSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MusicTreeData>(
      future: MusicTreeService.calculate(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        if (data.totalWorks == 0) {
          // 还没有作品时不显示卡片
          return const SizedBox.shrink();
        }

        // 本周创作数（暂时用 totalWorks 作为代理）
        final weeklyCount = data.totalWorks;

        return GestureDetector(
          onTap: () => context.go(AppRoutes.musicTree),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                // 小型音乐树
                SizedBox(
                  width: 64,
                  height: 64,
                  child: TreeVisual(
                    state: data.treeState,
                    height: 64,
                  ),
                ),

                const SizedBox(width: 14),

                // 统计信息（仅两行）
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('🌱 ',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '总创作: $weeklyCount 首',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('🔥 ',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '连续活跃: ${data.streakDays} 天',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 箭头
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
