import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/music_tree_data.dart';

/// 全局应用状态
class AppState extends ChangeNotifier {
  UserProfile? _userProfile;
  MusicTreeData? _treeData;
  bool _isOnline = false;
  final _locale = const Locale('zh', 'CN');

  UserProfile? get userProfile => _userProfile;
  MusicTreeData? get treeData => _treeData;
  bool get isOnline => _isOnline;
  Locale get locale => _locale;
  bool get hasCompletedOnboarding => _userProfile?.hasCompletedOnboarding ?? false;

  /// 设置用户档案
  void setUserProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  /// 更新音乐树数据
  void updateTreeData(MusicTreeData data) {
    _treeData = data;
    notifyListeners();
  }

  /// 更新网络状态
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  /// 完成新用户引导
  void completeOnboarding() {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(hasCompletedOnboarding: true);
      notifyListeners();
    }
  }
}
