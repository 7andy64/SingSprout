import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/humming_garden/humming_garden_page.dart';
import '../../features/humming_garden/recording_page.dart';
import '../../features/humming_garden/editor_page.dart';
import '../../shared/models/music_work.dart';
import '../../features/voice_post_office/post_office_page.dart';
import '../../features/voice_post_office/compose_page.dart';
import '../../features/music_tree/music_tree_page.dart';
import '../../features/mood_radio/mood_radio_page.dart';
import '../../features/field_sound_lab/field_sound_lab_page.dart';
import '../../features/rhythm_tribe/rhythm_tribe_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/privacy_settings_page.dart';
import '../../features/profile/works_page.dart';
import '../../features/profile/work_detail_page.dart';
import '../../features/profile/sounds_page.dart';
import '../../features/profile/ledger_page.dart';
import '../../features/profile/observation_page.dart';
import '../../features/profile/storage_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../constants/app_routes.dart';

/// 声芽路由配置 — 底部导航(5项) + 子页面
class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.hummingGarden,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('无法找到页面', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(state.error.toString(), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => GoRouter.of(context).go(AppRoutes.hummingGarden),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
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
        path: AppRoutes.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.works,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WorksPage(),
      ),
      GoRoute(
        path: AppRoutes.workDetail,
        name: 'work-detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final workId = state.uri.queryParameters['id'] ?? '';
          return WorkDetailPage(workId: workId);
        },
      ),
      GoRoute(
        path: AppRoutes.sounds,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SoundsPage(),
      ),
      GoRoute(
        path: AppRoutes.ledger,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LedgerPage(),
      ),
      GoRoute(
        path: AppRoutes.observation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ObservationPage(),
      ),
      GoRoute(
        path: AppRoutes.storage,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StoragePage(),
      ),
      GoRoute(
        path: AppRoutes.recording,
        name: 'recording',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RecordingPage(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final work =
              state.extra is MusicWork ? state.extra as MusicWork : null;
          if (work == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('错误')),
              body: const Center(child: Text('未找到作品数据，请返回重试')),
            );
          }
          return EditorPage(work: work);
        },
      ),
      GoRoute(
        path: AppRoutes.composeCard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final workId = state.uri.queryParameters['workId'];
          return ComposePage(initialWorkId: workId);
        },
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
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    // MVP 阶段显示 5 个 Tab：创作/表达/成长/连接/我的
    // P1 阶段将"节奏部落"加入扩展菜单
    return BottomNavigationBar(
      currentIndex: _calculateIndex(location),
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.mic_none),
          activeIcon: Icon(Icons.mic),
          label: '哼唱',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sentiment_satisfied),
          activeIcon: Icon(Icons.sentiment_satisfied),
          label: '心情',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.park),
          activeIcon: Icon(Icons.park),
          label: '音乐树',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail_outline),
          activeIcon: Icon(Icons.mail),
          label: '邮局',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: '我的',
        ),
      ],
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
