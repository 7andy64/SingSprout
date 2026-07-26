import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_config.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/update_dialog.dart';
import '../../shared/services/update_service.dart';
import '../../shared/services/file_storage_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';

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
    // 进入页面时从本地数据库加载用户数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLocalData();
      _checkStorage();
    });
  }

  Future<void> _checkStorage() async {
    try {
      final storage = FileStorageService();
      final bytes = await storage.totalStorageUsed();
      if (mounted) setState(() {
        _totalStorageBytes = bytes;
        _storageChecked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _storageChecked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final profile = appState.userProfile;
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
                      _ProfileHeader(profile: profile, loading: !dataLoaded),

                      const SizedBox(height: 16),

                      // 数据统计区
                      if (dataLoaded) ...[
                        _StatsSection(appState: appState),
                        const SizedBox(height: 16),
                      ],

                      // 低存储警告
                      if (_storageChecked && _totalStorageBytes > 100 * 1024 * 1024)
                        _LowStorageBanner(
                          totalBytes: _totalStorageBytes,
                          onTap: () => context.push(AppRoutes.storage),
                        ),

                      // 菜单列表
                      _MenuSection(
                        title: '创作',
                        items: [
                          _MenuItem(
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
                          _MenuItem(
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

                      _MenuSection(
                        title: '连接',
                        items: [
                          _MenuItem(
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
                          _MenuItem(
                            icon: Icons.people_outline_rounded,
                            label: '教师/家长观察窗',
                            onTap: () => context.push(AppRoutes.observation),
                          ),
                        ],
                      ),

                      _MenuSection(
                        title: '设置',
                        items: [
                          _MenuItem(
                            icon: Icons.pets_outlined,
                            label: '换一只守护动物',
                            onTap: () => _showAnimalPicker(profile),
                          ),
                          _MenuItem(
                            icon: Icons.edit_outlined,
                            label: '编辑资料',
                            onTap: () => _showEditProfile(profile),
                          ),
                          _MenuItem(
                            icon: Icons.lock_outline_rounded,
                            label: '隐私与安全',
                            onTap: () => context.push(AppRoutes.privacySettings),
                          ),
                          _MenuItem(
                            icon: Icons.storage_rounded,
                            label: '存储管理',
                            onTap: () => _showStorageManagement(),
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: '帮助与反馈',
                            onTap: () => _showHelpDialog(),
                          ),
                        ],
                      ),

                      _MenuSection(
                        title: '',
                        items: [
                          _MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: '关于声芽',
                            trailing: Text(
                              'V${AppConfig.version}',
                              style: const TextStyle(
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
                        animal.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text(
                        animal.displayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primaryGreen)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => Navigator.pop(ctx, animal),
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

  void _showEditProfile(UserProfile? profile) {
    if (profile == null) return;

    final controller = TextEditingController(text: profile.nickname);
    var disposed = false;

    void disposeController() {
      if (!disposed) {
        controller.dispose();
        disposed = true;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '输入你的昵称',
          ),
          maxLength: 12,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              disposeController();
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
              disposeController();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => disposeController());
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

// ══════════════════════════════════════════════════════════════════════════════
// 子组件
// ══════════════════════════════════════════════════════════════════════════════

/// 用户信息头部 — 头像、昵称、角色、陪伴动物
class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final bool loading;

  const _ProfileHeader({required this.profile, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          AnimalAvatar(
            animal: profile?.guardianAnimal ?? GuardianAnimal.panda,
            size: 80,
            speechBubble: hasProfile ? '嘿！今天想做什么？' : null,
          ),
          const SizedBox(height: 12),
          if (loading)
            Column(
              children: const [
                SizedBox(
                  width: 120,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              profile?.nickname ?? '新朋友',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (!loading && hasProfile) ...[
            // 角色徽章
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${profile!.role.emoji} ${profile!.role.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${profile!.guardianAnimal.displayName} 陪伴你',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatDate(profile!.createdAt)} 加入',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else if (!loading && !hasProfile) ...[
            Text(
              '${GuardianAnimal.panda.displayName} 陪伴你',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// 数据统计区 — 作品、声音、明信片计数
class _StatsSection extends StatelessWidget {
  final AppState appState;
  const _StatsSection({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.music_note_rounded,
            label: '作品',
            count: appState.totalWorks,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.graphic_eq_rounded,
            label: '声音',
            count: appState.totalSounds,
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.mail_outline_rounded,
            label: '明信片',
            count: appState.totalCards,
            color: const Color(0xFFFF6D00),
          ),
        ],
      ),
    );
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单分组
class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

/// 低存储警告横幅
class _LowStorageBanner extends StatelessWidget {
  final int totalBytes;
  final VoidCallback onTap;

  const _LowStorageBanner({required this.totalBytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, size: 20, color: Color(0xFFE67E22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '存储空间已使用 $mb MB',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '点击管理存储，不会自动删除你的作品',
                      style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF856404), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单项
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            const Icon(
              Icons.chevron_right,
              color: AppTheme.divider,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
