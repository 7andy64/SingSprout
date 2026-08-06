/// 守护动物类型
enum GuardianAnimal {
  panda('小熊猫咕咕', '🐼', '咕咕'),
  deer('小鹿斑斑', '🦌', '斑比'),
  tit('蓝羽山雀', '🐦', '啾啾'),
  frog('翠蛙呱呱', '🐸', '呱呱'),
  ladybug('七星瓢虫', '🐞', '星星'),
  dog('小黄狗旺财', '🐕', '旺财'),
  cat('小花猫咪咪', '🐱', '咪咪'),
  duck('小鸭子嘎嘎', '🦆', '嘎嘎'),
  goat('小山羊咩咩', '🐐', '咩咩'),
  elf('小精灵阿贝贝', '🧚', '阿贝贝'),
  elephant('小象乐乐', '🐘', '乐乐'),
  fox('小狐狸小狸', '🦊', '小狸'),
  hedgehog('小刺猬团团', '🦔', '团团'),
  squirrel('小松鼠松松', '🐿️', '松松'),
  rabbit('小兔子跳跳', '🐰', '跳跳');

  const GuardianAnimal(this.displayName, this.emoji, this.shortName);
  final String displayName;
  final String emoji;
  final String shortName;
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
