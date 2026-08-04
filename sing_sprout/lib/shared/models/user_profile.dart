/// 守护动物类型
enum GuardianAnimal {
  panda('小熊猫咕咕', '🐼'),
  deer('小鹿斑斑', '🦌'),
  tit('蓝羽山雀', '🐦'),
  frog('翠蛙呱呱', '🐸'),
  ladybug('七星瓢虫', '🐞');

  const GuardianAnimal(this.displayName, this.emoji);
  final String displayName;
  final String emoji;
}

/// 用户身份
enum UserRole {
  student('学生', '🧒'),
  teacher('老师', '👩‍🏫'),
  parent('家长', '👨‍👩‍👧');

  const UserRole(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 本地用户档案
class UserProfile {
  final String localId;
  final String nickname;
  final String voiceBaselinePath;
  final GuardianAnimal guardianAnimal;
  final UserRole role;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;

  const UserProfile({
    required this.localId,
    required this.nickname,
    required this.voiceBaselinePath,
    required this.guardianAnimal,
    this.role = UserRole.student,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
  });

  factory UserProfile.create({
    required String nickname,
    required String voiceBaselinePath,
    GuardianAnimal guardianAnimal = GuardianAnimal.panda,
    UserRole role = UserRole.student,
  }) {
    final now = DateTime.now();
    return UserProfile(
      localId: now.millisecondsSinceEpoch.toString(),
      nickname: nickname,
      voiceBaselinePath: voiceBaselinePath,
      guardianAnimal: guardianAnimal,
      role: role,
      createdAt: now,
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? voiceBaselinePath,
    GuardianAnimal? guardianAnimal,
    UserRole? role,
    bool? hasCompletedOnboarding,
  }) {
    return UserProfile(
      localId: localId,
      nickname: nickname ?? this.nickname,
      voiceBaselinePath: voiceBaselinePath ?? this.voiceBaselinePath,
      guardianAnimal: guardianAnimal ?? this.guardianAnimal,
      role: role ?? this.role,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt,
    );
  }
}
