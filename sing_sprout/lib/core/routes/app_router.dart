import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/humming_garden/humming_garden_page.dart';
import '../../features/humming_garden/creative_flow_page.dart';
import '../../features/humming_garden/recording_page.dart';
import '../../features/humming_garden/editor_page.dart';
import '../../shared/models/music_work.dart';
import '../../features/voice_post_office/post_office_page.dart';
import '../../features/voice_post_office/compose_page.dart';
import '../../features/mood_radio/mood_radio_page.dart';
import '../../features/music_tree/music_tree_page.dart';
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
import '../../shared/widgets/notification_badge.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/role_permissions.dart';
import '../constants/app_routes.dart';
import '../theme/app_theme.dart';

/// 声芽路由配置 — 底部导航 5 花瓣（哼唱 / 心情 / 音乐树 / 邮局 / 我的）
class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// 路由 → 所需权限映射
  static final _protectedRoutes = <String, Feature>{
    AppRoutes.creativeFlow: Feature.createMusic,
    AppRoutes.recording: Feature.createMusic,
    AppRoutes.editor: Feature.editWork,
    AppRoutes.observation: Feature.accessObservation,
  };

  static String? _guardRedirect(BuildContext context, GoRouterState state) {
    final feature = _protectedRoutes[state.uri.path];
    if (feature == null) return null; // 非保护路由，放行

    final appState = context.read<AppState>();
    final role = appState.userProfile?.role ?? UserRole.student;

    if (!rolePermissions[feature]!.contains(role)) {
      // 无权限 → 重定向到花园页
      return AppRoutes.hummingGarden;
    }
    return null; // 允许访问
  }

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.hummingGarden,
    redirect: _guardRedirect,
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
              child: const Text('返回花园'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      // ── 底部导航壳（5 Tab） ──
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
            path: AppRoutes.fieldSoundLab,
            pageBuilder: (context, state) => _buildTabPage(
              const FieldSoundLabPage(),
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
        path: AppRoutes.moodRadio,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MoodRadioPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.creativeFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreativeFlowPage(),
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
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

/// 底部导航壳 — 5 花瓣
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

/// 底部导航栏（5 项）— 使用 emoji 避免 Material Icons 字体加载问题
class _BottomNavBar extends StatelessWidget {
  // emoji + 标签映射
  static const _tabs = [
    ('🎤', '哼唱'),
    ('🎧', '田野'),
    ('🌳', '音乐树'),
    ('📮', '邮局'),
    ('👤', '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _calculateIndex(location);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final selected = i == index;
              final tabWidget = GestureDetector(
                onTap: () => _onTap(context, i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tabs[i].$1,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tabs[i].$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              // 邮局 tab（index 3）加红点
              if (i == 3) {
                return Consumer<NotificationProvider>(
                  builder: (context, notif, _) {
                    return NotificationBadge(
                      count: notif.unreadCount,
                      child: tabWidget,
                    );
                  },
                );
              }
              return tabWidget;
            }),
          ),
        ),
      ),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith(AppRoutes.hummingGarden)) return 0;
    if (location.startsWith(AppRoutes.fieldSoundLab)) return 1;
    if (location.startsWith(AppRoutes.musicTree)) return 2;
    if (location.startsWith(AppRoutes.postOffice)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    final routes = [
      AppRoutes.hummingGarden,
      AppRoutes.fieldSoundLab,
      AppRoutes.musicTree,
      AppRoutes.postOffice,
      AppRoutes.profile,
    ];
    // 点击邮局时刷新通知计数
    if (index == 3) {
      context.read<NotificationProvider>().refresh();
    }
    GoRouter.of(context).go(routes[index]);
  }
}
