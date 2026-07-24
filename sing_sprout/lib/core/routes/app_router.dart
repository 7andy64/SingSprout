import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/humming_garden/humming_garden_page.dart';
import '../../features/humming_garden/recording_page.dart';
import '../../features/humming_garden/editor_page.dart';
import '../../features/voice_post_office/post_office_page.dart';
import '../../features/voice_post_office/compose_page.dart';
import '../../features/music_tree/music_tree_page.dart';
import '../../features/mood_radio/mood_radio_page.dart';
import '../../features/field_sound_lab/field_sound_lab_page.dart';
import '../../features/rhythm_tribe/rhythm_tribe_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/privacy_settings_page.dart';
import '../constants/app_routes.dart';
import '../theme/app_theme.dart';

/// 声芽路由配置 — 底部导航(5项) + 子页面
class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.hummingGarden,
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.hummingGarden,
            pageBuilder: (context, state) => _buildTabPage(
              const HummingGardenPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.moodRadio,
            pageBuilder: (context, state) => _buildTabPage(
              const MoodRadioPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.musicTree,
            pageBuilder: (context, state) => _buildTabPage(
              const MusicTreePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.postOffice,
            pageBuilder: (context, state) => _buildTabPage(
              const PostOfficePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => _buildTabPage(
              const ProfilePage(),
            ),
          ),
        ],
      ),

      // ── 独立子页面 ──
      GoRoute(
        path: AppRoutes.recording,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RecordingPage(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final workId = state.uri.queryParameters['id'] ?? '';
          return EditorPage(workId: workId);
        },
      ),
      GoRoute(
        path: AppRoutes.composeCard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ComposePage(),
      ),
      GoRoute(
        path: AppRoutes.privacySettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacySettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.fieldSoundLab,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FieldSoundLabPage(),
      ),
      GoRoute(
        path: AppRoutes.rhythmTribe,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RhythmTribePage(),
      ),
    ],
  );

  static Page<dynamic> _buildTabPage(Widget child) {
    return CustomTransitionPage(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ).drive(Tween(begin: 0.0, end: 1.0)),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

/// 底部导航壳
class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatefulWidget {
  const _BottomNavBar();

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar>
    with TickerProviderStateMixin {
  static const _navItems = [
    ('🎤', '哼唱'),
    ('🌈', '心情'),
    ('🌱', '音乐树'),
    ('💌', '邮局'),
    ('🐼', '我的'),
  ];

  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_navItems.length, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      // First tab starts selected
      if (i == 0) ctrl.value = 1.0;
      return ctrl;
    });
    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.15)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _animateTo(int index) {
    for (int i = 0; i < _controllers.length; i++) {
      if (i == index) {
        _controllers[i].forward();
      } else {
        _controllers[i].reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    final iconFontSize = (24 * scale).clamp(20.0, 28.0);
    final labelFontSize = (12 * scale).clamp(11.0, 14.0);
    final index = _calculateIndex(location);

    // Drive animation to match current tab
    _animateTo(index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final isSelected = i == index;
              return _NavItem(
                emoji: _navItems[i].$1,
                label: _navItems[i].$2,
                fontSize: iconFontSize,
                labelFontSize: labelFontSize,
                isSelected: isSelected,
                scaleAnimation: _scaleAnimations[i],
                showBadge: i == 4, // badge on profile tab
                onTap: () {
                  _onTap(context, i);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith(AppRoutes.hummingGarden)) return 0;
    if (location.startsWith(AppRoutes.moodRadio)) return 1;
    if (location.startsWith(AppRoutes.musicTree)) return 2;
    if (location.startsWith(AppRoutes.postOffice)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    final routes = [
      AppRoutes.hummingGarden,
      AppRoutes.moodRadio,
      AppRoutes.musicTree,
      AppRoutes.postOffice,
      AppRoutes.profile,
    ];
    GoRouter.of(context).go(routes[index]);
  }
}

class _NavItem extends StatelessWidget {
  final String emoji;
  final String label;
  final double fontSize;
  final double labelFontSize;
  final bool isSelected;
  final Animation<double> scaleAnimation;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.emoji,
    required this.label,
    required this.fontSize,
    required this.labelFontSize,
    required this.isSelected,
    required this.scaleAnimation,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: scaleAnimation.value,
          child: child,
        ),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(emoji, style: TextStyle(fontSize: fontSize)),
                  if (showBadge)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
