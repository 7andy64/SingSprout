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

/// 声芽路由配置 — 底部导航(5项) + 子页面
class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.hummingGarden,
    routes: [
      // ── 底部导航壳 ──
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.hummingGarden,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HummingGardenPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.moodRadio,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MoodRadioPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.musicTree,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MusicTreePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.postOffice,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PostOfficePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfilePage(),
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
}

/// 底部导航壳 — 5 个花瓣入口
class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  static const _navItems = [
    ('🎤', '哼唱'),
    ('🌈', '心情'),
    ('🌱', '音乐树'),
    ('💌', '邮局'),
    ('🐼', '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    final iconFontSize = (24 * scale).clamp(20.0, 28.0);
    final labelFontSize = (12 * scale).clamp(11.0, 14.0);
    final index = _calculateIndex(location);

    return BottomNavigationBar(
      currentIndex: index,
      onTap: (i) => _onTap(context, i),
      selectedIconTheme: IconThemeData(size: iconFontSize),
      unselectedIconTheme: IconThemeData(size: iconFontSize),
      selectedLabelStyle: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: labelFontSize),
      items: List.generate(_navItems.length, (i) {
        return BottomNavigationBarItem(
          icon: Text(
            _navItems[i].$1,
            style: TextStyle(fontSize: iconFontSize),
          ),
          activeIcon: Text(
            _navItems[i].$1,
            style: TextStyle(fontSize: iconFontSize),
          ),
          label: _navItems[i].$2,
        );
      }),
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
