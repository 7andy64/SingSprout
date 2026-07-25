import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/music_work.dart';
import '../models/user_profile.dart';
import '../models/music_tree_data.dart';
import '../services/work_repository.dart';

class AppState extends ChangeNotifier {
  UserProfile? _userProfile;
  MusicTreeData? _treeData;
  bool _isOnline = false;
  final _locale = const Locale('zh', 'CN');
  final List<MusicWork> _works = [];

  UserProfile? get userProfile => _userProfile;
  MusicTreeData? get treeData => _treeData;
  bool get isOnline => _isOnline;
  Locale get locale => _locale;
  bool get hasCompletedOnboarding => _userProfile?.hasCompletedOnboarding ?? false;
  List<MusicWork> get works => List.unmodifiable(_works);

  void setUserProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  void updateTreeData(MusicTreeData data) {
    _treeData = data;
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  void completeOnboarding() {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(hasCompletedOnboarding: true);
      notifyListeners();
    }
  }

  void addWork(MusicWork work) {
    _works.insert(0, work);
    WorkRepository().addWork(work);
    notifyListeners();
  }

  void deleteWork(String id) {
    _works.removeWhere((w) => w.id == id);
    WorkRepository().deleteWork(id);
    notifyListeners();
  }

  Future<void> loadWorks() async {
    final works = await WorkRepository().getWorks();
    _works
      ..clear()
      ..addAll(works);
    notifyListeners();
  }
}
