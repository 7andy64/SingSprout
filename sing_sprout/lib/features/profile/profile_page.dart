import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_config.dart';
import '../../shared/widgets/update_dialog.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/economy_provider.dart';
import 'widgets/profile_widgets.dart';
import '../../shared/services/update_service.dart';
import '../../shared/services/file_storage_service.dart';
import '../../shared/services/role_permissions.dart';
import '../../shared/widgets/role_gate.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/theme_provider.dart';

/// 个人中心 — MVP P0 功能
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _totalStorageBytes = 0;
  bool _storageChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLocalData();
      _checkStorage();
    });
  }

  Future<void> _checkStorage() async {
    try {
      final storage = FileStorageService();
      final bytes = await storage.totalStorageUsed();
      if (mounted) {
        setState(() {
          _totalStorageBytes = bytes;
          _storageChecked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _storageChecked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final profile = appState.userProfile;
        final role = profile?.role ?? UserRole.student;
        final dataLoaded = appState.dataLoaded;

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: dataLoaded && profile == null
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      // 用户信息卡片
                      ProfileHeader(profile: profile, loading: !dataLoaded),

                      const SizedBox(height: 16),

                      // 数据统计区
                      if (dataLoaded) ...[
                        StatsSection(appState: appState),
                        const SizedBox(height: 16),
                      ],

                      // 低存储警告
                      if (_storageChecked && _totalStorageBytes > 100 * 1024 * 1024)
                        LowStorageBanner(
                          totalBytes: _totalStorageBytes,
                          onTap: () => context.push(AppRoutes.storage),
                        ),

                      // 菜单列表
                      MenuSection(
                        title: '创作',
                        items: [
                          MenuItem(
                            icon: Icons.music_note_rounded,
                            label: '我的作品集',
                            trailing: dataLoaded
                                ? Text(
                                    '${appState.totalWorks}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : null,
                            onTap: () => context.push(AppRoutes.works),
                          ),
                          MenuItem(
                            icon: Icons.library_music_outlined,
                            label: '我的声音库',
                            trailing: dataLoaded
                                ? Text(
                                    '${appState.totalSounds}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : null,
                            onTap: () => context.push(AppRoutes.sounds),
                          ),
                        ],
                      ),

                      MenuSection(
                        title: '连接',
                        items: [
                          MenuItem(
                            icon: Icons.mail_outline_rounded,
                            label: '家庭音乐账本',
                            trailing: dataLoaded
                                ? Text(
                                    '${appState.totalCards}张',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : null,
                            onTap: () => context.push(AppRoutes.ledger),
                          ),
                          if (RoleGate.isAllowed(Feature.accessObservation, role))
                            MenuItem(
                              icon: Icons.people_outline_rounded,
                              label: '教师/家长观察窗',
                              onTap: () => context.push(AppRoutes.observation),
                            ),
                        ],
                      ),

                      MenuSection(
                        title: '趣味',
                        items: [
                          MenuItem(
                            icon: Icons.storefront_outlined,
                            label: '森林集市',
                            trailing: Consumer<EconomyProvider>(
                              builder: (_, eco, __) => Text(
                                '🌰 ${eco.balance}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ),
                            onTap: () => context.push(AppRoutes.shop),
                          ),
                          MenuItem(
                            icon: Icons.backpack_outlined,
                            label: '我的背包',
                            onTap: () => context.push(AppRoutes.inventory),
                          ),
                          MenuItem(
                            icon: Icons.games_outlined,
                            label: '节奏部落',
                            trailing: const Text(
                              '玩游戏赚松果',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            onTap: () => context.push(AppRoutes.rhythmTribe),
                          ),
                        ],
                      ),
                      MenuSection(
                        title: '设置',
                        items: [
                          MenuItem(
                            icon: Icons.pets_outlined,
                            label: '换一只守护动物',
                            onTap: () => _showAnimalPicker(profile),
                          ),
                          MenuItem(
                            icon: Icons.edit_outlined,
                            label: '编辑资料',
                            onTap: () => _showEditProfile(profile),
                          ),
                          Builder(
                            builder: (context) {
                              final tp = context.watch<ThemeProvider>();
                              return MenuItem(
                                icon: tp.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                label: '切换主题',
                                trailing: Text(
                                  tp.isDark ? '夜间' : '白天',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                onTap: () => tp.toggle(),
                              );
                            },
                          ),
                          if (RoleGate.isAllowed(Feature.accessPrivacySettings, role))
                            MenuItem(
                              icon: Icons.lock_outline_rounded,
                              label: '隐私与安全',
                              onTap: () => context.push(AppRoutes.privacySettings),
                            ),
                          MenuItem(
                            icon: Icons.storage_rounded,
                            label: '存储管理',
                            onTap: () => _showStorageManagement(),
                          ),
                          MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: '帮助与反馈',
                            onTap: () => _showHelpDialog(),
                          ),
                        ],
                      ),

                      MenuSection(
                        title: '',
                        items: [
                          MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: '关于声芽',
                            trailing: const Text(
                              'V${AppConfig.version}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            onTap: () async {
                              final info = await UpdateService().checkForUpdate();
                              if (info != null && context.mounted) {
                                UpdateDialog.show(context, info);
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ── 空状态：引导创建档案 ──

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐼', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              '欢迎来到声芽！',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '创建你的音乐档案，\n让小动物们陪伴你开始创作之旅',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await context.push(AppRoutes.onboarding);
                // 从引导页返回后刷新数据
                if (mounted) {
                  context.read<AppState>().loadLocalData();
                }
              },
              label: const Text('创建我的档案'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 守护动物选择器 ──

  void _showAnimalPicker(UserProfile? profile) {
    showModalBottomSheet<GuardianAnimal>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '选择你的守护动物',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ...GuardianAnimal.values.map((animal) {
                  final isSelected = profile?.guardianAnimal == animal;
                  final economy = context.read<EconomyProvider>();
                  final owned = economy.isAnimalOwned(animal.name);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: ListTile(
                      leading: Text(
                        owned ? animal.emoji : '🔒',
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text(
                        owned ? animal.displayName : '${animal.displayName}（需购买）',
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: owned
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primaryGreen,)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: owned
                          ? () => Navigator.pop(ctx, animal)
                          : () {
                              Navigator.pop(ctx);
                              context.push('/shop');
                            },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    ).then((selectedAnimal) async {
      // 从 AppState 读取最新 profile，避免闭包时效问题
      final currentProfile = context.read<AppState>().userProfile;
      if (selectedAnimal != null &&
          currentProfile != null &&
          selectedAnimal != currentProfile.guardianAnimal) {
        await context
            .read<AppState>()
            .setUserProfile(currentProfile.copyWith(guardianAnimal: selectedAnimal));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('守护动物已切换为${selectedAnimal.displayName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  // ── 编辑资料弹窗 ──

  Future<void> _showEditProfile(UserProfile? profile) async {
    if (profile == null) return;

    final controller = TextEditingController(text: profile.nickname);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '昵称',
              hintText: '输入你的昵称',
            ),
            maxLength: 12,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != profile.nickname) {
                await context
                    .read<AppState>()
                    .setUserProfile(profile.copyWith(nickname: newName));
              }
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // 兜底：确保 controller 被释放（正常情况已被回调中 dispose）
    try {
      controller.dispose();
    } catch (_) { /* already disposed */ }
  }

  // ── 存储管理 ──

  void _showStorageManagement() {
    context.push(AppRoutes.storage);
  }

  // ── 帮助与反馈弹窗 ──

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('帮助与反馈'),
        content: const Text(
          '如有任何问题或建议，欢迎联系我们：\n\n'
          '📧 hello@singsprout.app\n'
          '🌐 singsprout.app',
          style: TextStyle(height: 1.6, color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
