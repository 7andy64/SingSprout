import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';

/// 首次使用引导流程
///
/// 3 步完成用户档案创建：
/// 1. 选择守护动物
/// 2. 选择身份 + 输入昵称
/// 3. 确认并开始
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _nicknameController = TextEditingController();
  int _currentStep = 0;

  GuardianAnimal _selectedAnimal = GuardianAnimal.panda;
  UserRole _selectedRole = UserRole.student;

  static const _totalSteps = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入你的昵称～'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 创建用户档案
    final profile = UserProfile.create(
      nickname: nickname,
      voiceBaselinePath: '', // 首次录音后填充
      guardianAnimal: _selectedAnimal,
      role: _selectedRole,
    );

    // 持久化
    await context.read<AppState>().setUserProfile(profile);

    if (mounted) {
      // 返回主页（自动刷新"我的"页面）
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部进度 + 跳过
            _buildHeader(),

            // 步骤页面
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _StepPickAnimal(
                    selected: _selectedAnimal,
                    onSelected: (a) => setState(() => _selectedAnimal = a),
                  ),
                  _StepTellAboutYou(
                    controller: _nicknameController,
                    selectedRole: _selectedRole,
                    onRoleChanged: (r) => setState(() => _selectedRole = r),
                  ),
                  _StepReady(
                    animal: _selectedAnimal,
                    nickname: _nicknameController.text.trim(),
                    role: _selectedRole,
                  ),
                ],
              ),
            ),

            // 底部按钮
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        children: [
          // 步骤指示器
          Row(
            children: List.generate(_totalSteps, (i) {
              final isActive = i <= _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryGreen
                      : AppTheme.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const Spacer(),

          // 跳过按钮
          if (_currentStep < _totalSteps - 1)
            TextButton(
              onPressed: () {
                // 跳到最后一步，使用默认值
                _pageController.animateToPage(
                  _totalSteps - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text(
                '跳过',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Row(
        children: [
          if (_currentStep > 0)
            GestureDetector(
              onTap: _previousPage,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
              ),
            ),

          const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton(
              onPressed: isLastStep ? _completeOnboarding : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep
                    ? AppTheme.primaryWarm
                    : AppTheme.primaryGreen,
                foregroundColor:
                    isLastStep ? AppTheme.textPrimary : Colors.white,
              ),
              child: Text(isLastStep ? '✨ 开始探索' : '下一步'),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 步骤 1：选择守护动物
// ══════════════════════════════════════════════════════════════════════════════

class _StepPickAnimal extends StatelessWidget {
  final GuardianAnimal selected;
  final ValueChanged<GuardianAnimal> onSelected;

  const _StepPickAnimal({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 大 Emoji
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              selected.emoji,
              key: ValueKey(selected),
              style: const TextStyle(fontSize: 80),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            '选择你的音乐伙伴',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '一位守护动物会陪伴你的音乐旅程',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // 动物选择网格
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: GuardianAnimal.values.map((animal) {
              final isSelected = selected == animal;
              return GestureDetector(
                onTap: () => onSelected(animal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 130,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.4),
                            width: 2,
                          )
                        : Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Text(animal.emoji, style: const TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text(
                        animal.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 步骤 2：身份 + 昵称
// ══════════════════════════════════════════════════════════════════════════════

class _StepTellAboutYou extends StatelessWidget {
  final TextEditingController controller;
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  const _StepTellAboutYou({
    required this.controller,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '介绍一下你自己',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '我们来更好地认识你',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // 身份选择
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '我是',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: UserRole.values.map((role) {
              final isSelected = selectedRole == role;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: role != UserRole.values.last ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => onRoleChanged(role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: AppTheme.primaryGreen.withOpacity(0.4),
                                width: 2,
                              )
                            : Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        children: [
                          Text(role.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(
                            role.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 昵称输入
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '我的昵称',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: '输入你的昵称',
              counterText: '',
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 步骤 3：确认
// ══════════════════════════════════════════════════════════════════════════════

class _StepReady extends StatelessWidget {
  final GuardianAnimal animal;
  final String nickname;
  final UserRole role;

  const _StepReady({
    required this.animal,
    required this.nickname,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = nickname.isEmpty ? '新朋友' : nickname;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            animal.emoji,
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 20),

          const Text(
            '准备好了吗？',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$displayName，\n和${animal.displayName}一起开始音乐之旅吧！',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // 档案预览卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Text(animal.emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${role.emoji} ${role.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
