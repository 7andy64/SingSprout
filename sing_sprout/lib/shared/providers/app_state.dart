import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/music_tree_data.dart';
import '../models/music_work.dart';
import '../models/sound_sample.dart';
import '../models/voice_card.dart';
import '../repositories/work_repository.dart';
import '../repositories/sound_repository.dart';
import '../repositories/voice_card_repository.dart';
import '../repositories/user_profile_repository.dart';

/// 全局应用状态
///
/// 管理用户档案、音乐树数据、作品列表等全局状态，
/// 通过 Repository 层与 SQLite 本地数据库交互。
class AppState extends ChangeNotifier {
  // ── Repositories ──
  final WorkRepository _workRepo = WorkRepository();
  final SoundRepository _soundRepo = SoundRepository();
  final VoiceCardRepository _cardRepo = VoiceCardRepository();
  final UserProfileRepository _profileRepo = UserProfileRepository();

  // ── 状态 ──
  UserProfile? _userProfile;
  MusicTreeData? _treeData;
  bool _isOnline = false;
  final _locale = const Locale('zh', 'CN');

  // 作品列表（缓存，避免频繁读库）
  List<MusicWork> _works = [];
  List<SoundSample> _sounds = [];
  List<VoiceCard> _cards = [];

  bool _dataLoaded = false;

  // ── Getters ──

  UserProfile? get userProfile => _userProfile;
  MusicTreeData? get treeData => _treeData;
  bool get isOnline => _isOnline;
  Locale get locale => _locale;
  bool get hasCompletedOnboarding =>
      _userProfile?.hasCompletedOnboarding ?? false;
  bool get dataLoaded => _dataLoaded;

  List<MusicWork> get works => List.unmodifiable(_works);
  List<SoundSample> get sounds => List.unmodifiable(_sounds);
  List<VoiceCard> get cards => List.unmodifiable(_cards);

  List<MusicWork> get favoriteWorks =>
      _works.where((w) => w.isFavorite).toList();

  int get totalWorks => _works.length;
  int get totalSounds => _sounds.length;
  int get totalCards => _cards.length;

  // ── 初始化：从本地数据库加载所有数据 ──

  /// 从 SQLite 加载用户档案和所有本地数据。
  /// Web 端 SQLite 不可用，跳过加载（使用空数据 + 显示引导页）。
  Future<void> loadLocalData() async {
    if (_dataLoaded) return;

    if (kIsWeb) {
      // Web 端：跳过数据库加载，显示空状态引导
      _dataLoaded = true;
      notifyListeners();
      return;
    }

    // 加载用户档案
    _userProfile = await _profileRepo.get();

    // 加载所有作品、声音、明信片
    _works = await _workRepo.getAll();
    _sounds = await _soundRepo.getAll();
    _cards = await _cardRepo.getAll();

    // 根据数据重新计算音乐树状态
    _treeData = _buildTreeData();

    _dataLoaded = true;
    notifyListeners();
  }

  /// 从现有数据构建音乐树数据。
  MusicTreeData _buildTreeData() {
    final lastActive =
        _works.isNotEmpty ? _works.first.updatedAt : DateTime.now();
    return MusicTreeData(
      totalWorks: _works.length,
      sharedCards: _cards.where((c) => c.direction == VoiceCardDirection.sent).length,
      receivedReplies:
          _cards.where((c) => c.direction == VoiceCardDirection.received).length,
      lastActiveDate: lastActive,
    );
  }

  // ── 用户档案操作 ──

  Future<void> setUserProfile(UserProfile profile) async {
    _userProfile = profile;
    if (!kIsWeb) {
      await _profileRepo.save(profile);
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(hasCompletedOnboarding: true);
      if (!kIsWeb) {
        await _profileRepo.save(_userProfile!);
      }
      notifyListeners();
    }
  }

  // ── 作品操作 ──

  /// 添加/保存作品（写入 SQLite + 更新内存，Web 端仅内存）。
  Future<void> addWork(MusicWork work) async {
    if (!kIsWeb) await _workRepo.insert(work);
    _works.insert(0, work);
    _updateTree();
    notifyListeners();
  }

  /// 更新作品。
  Future<void> updateWork(MusicWork work) async {
    if (!kIsWeb) await _workRepo.update(work);
    final index = _works.indexWhere((w) => w.id == work.id);
    if (index != -1) {
      _works[index] = work;
    }
    notifyListeners();
  }

  /// 删除作品（同时删除关联文件）。
  Future<void> deleteWork(String id) async {
    if (!kIsWeb) await _workRepo.delete(id);
    _works.removeWhere((w) => w.id == id);
    _updateTree();
    notifyListeners();
  }

  /// 切换作品收藏状态。
  Future<void> toggleFavorite(String id) async {
    if (!kIsWeb) await _workRepo.toggleFavorite(id);
    final index = _works.indexWhere((w) => w.id == id);
    if (index != -1) {
      _works[index] = _works[index].copyWith(
        isFavorite: !_works[index].isFavorite,
      );
    }
    notifyListeners();
  }

  /// 重新从数据库加载作品列表。
  Future<void> refreshWorks() async {
    if (!kIsWeb) _works = await _workRepo.getAll();
    _updateTree();
    notifyListeners();
  }

  // ── 声音样本操作 ──

  Future<void> addSound(SoundSample sample) async {
    if (!kIsWeb) await _soundRepo.insert(sample);
    _sounds.insert(0, sample);
    notifyListeners();
  }

  Future<void> deleteSound(String id) async {
    if (!kIsWeb) await _soundRepo.delete(id);
    _sounds.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ── 明信片操作 ──

  Future<void> addVoiceCard(VoiceCard card) async {
    if (!kIsWeb) await _cardRepo.insert(card);
    _cards.insert(0, card);
    _updateTree();
    notifyListeners();
  }

  Future<void> markCardAsRead(String id) async {
    if (!kIsWeb) await _cardRepo.markAsRead(id);
    notifyListeners();
  }

  // ── 音乐树 ──

  void updateTreeData(MusicTreeData data) {
    _treeData = data;
    notifyListeners();
  }

  void _updateTree() {
    _treeData = _buildTreeData();
  }

  // ── 网络状态 ──

  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }
}
