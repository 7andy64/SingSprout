import '../../shared/models/user_profile.dart';

/// 需要角色门控的功能点
enum Feature {
  createMusic,            // 哼唱创作（录音+编曲）
  editWork,               // 编辑作品
  deleteWork,             // 删除作品
  changeIdentityPassword, // 修改身份切换密码
  accessObservation,      // 查看观察窗
  accessPrivacySettings,  // 访问隐私设置页
}

/// 每个功能允许的角色集合 — 权限规则的单一真相源
const rolePermissions = <Feature, Set<UserRole>>{
  Feature.createMusic:           {UserRole.student, UserRole.teacher},
  Feature.editWork:              {UserRole.student, UserRole.teacher},
  Feature.deleteWork:            {UserRole.student, UserRole.teacher},
  Feature.changeIdentityPassword:{UserRole.parent},
  Feature.accessObservation:     {UserRole.teacher, UserRole.parent},
  Feature.accessPrivacySettings: {UserRole.student, UserRole.teacher, UserRole.parent},
};
