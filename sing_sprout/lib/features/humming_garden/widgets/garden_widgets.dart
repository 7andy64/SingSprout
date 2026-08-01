import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/app_state.dart';
import 'work_tree_card.dart';

// ═══ Quick action chip ═══

class QuickActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.06),
            AppTheme.primaryWarm.withValues(alpha: 0.04),
          ],),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,),),
        ],),
      ),
    );
  }
}

// ═══ Mini energy bar ═══

class MiniEnergyBar extends StatelessWidget {
  final double value;
  const MiniEnergyBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final color =
        Color.lerp(AppTheme.primarySoil, AppTheme.primaryGreen, value)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ═══ Recent works section ═══

class RecentWorksSection extends StatefulWidget {
  const RecentWorksSection({super.key});

  @override
  State<RecentWorksSection> createState() => _RecentWorksSectionState();
}

class _RecentWorksSectionState extends State<RecentWorksSection> {
  final _recentScroll = ScrollController();
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _appeared = true);
    });
  }

  @override
  void dispose() {
    _recentScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final works = context.watch<AppState>().works;
    final recent = works.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('最近作品',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,),),
          if (works.isNotEmpty)
            TextButton(
              onPressed: () => context.push(AppRoutes.works),
              child: const Text('查看全部'),
            ),
        ],),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const EmptyWorksPlaceholder()
        else
          SizedBox(
            height: 158,
            child: ListView.separated(
              controller: _recentScroll,
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _appeared
                    ? WorkTreeCard(
                        work: recent[index], delayMs: index * 80,)
                    : const SizedBox.shrink();
              },
            ),
          ),
      ],),
    );
  }
}

// ═══ Stat cards ═══

class StatCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const StatCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.bgWarm.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,),),
        const SizedBox(height: 16),
        ...children,
      ],),
    );
  }
}

class StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String? subtitle;
  const StatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13,),),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11,),),
      ],),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontSize: 15,),),
    ],);
  }
}

class MoodDayChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const MoodDayChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,),),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.7),),),
        ],),
      ),
    );
  }
}
