import 'package:flutter/material.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/services/role_permissions.dart';

/// 角色门控组件
///
/// 根据当前用户角色决定是否显示子组件。
///
/// 用法：
/// ```dart
/// RoleGate(
///   feature: Feature.createMusic,
///   role: profile.role,
///   child: ElevatedButton(...),
/// )
///
/// // 带无权限提示：
/// RoleGate(
///   feature: Feature.createMusic,
///   role: profile.role,
///   fallback: Text('当前身份不支持此功能'),
///   child: RecordButton(...),
/// )
/// ```
class RoleGate extends StatelessWidget {
  const RoleGate({
    super.key,
    required this.feature,
    required this.role,
    required this.child,
    this.fallback,
  });

  final Feature feature;
  final UserRole role;
  final Widget child;
  final Widget? fallback;

  /// 检查指定功能对指定角色是否可用
  static bool isAllowed(Feature feature, UserRole role) {
    return rolePermissions[feature]?.contains(role) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (isAllowed(feature, role)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
