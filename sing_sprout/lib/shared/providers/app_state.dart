import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/music_work.dart';
import '../models/user_profile.dart';
import '../models/music_tree_data.dart';
import '../models/sound_sample.dart';
import '../models/voice_card.dart';
import '../repositories/work_repository.dart';
import '../repositories/sound_repository.dart';
import '../repositories/voice_card_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/file_storage_service.dart';

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
  String? _loadError; // 加载失败时的错误信息

  // ── Getters ──

  UserProfile? get userProfile => _userProfile;
  MusicTreeData? get treeData => _treeData;
  bool get isOnline => _isOnline;
  Locale get locale => _locale;
  bool get hasCompletedOnboarding =>
      _userProfile?.hasCompletedOnboarding ?? false;
  bool get dataLoaded => _dataLoaded;
  String? get loadError => _loadError;

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
  Future<void> loadLocalData({bool force = false}) async {
    if (_dataLoaded && !force) return;

    if (force) {
      _dataLoaded = false;
      _loadError = null;
    }

    if (kIsWeb) {
      // Web 端：跳过数据库加载，显示空状态引导
      _dataLoaded = true;
      notifyListeners();
      return;
    }

    try {
      // 加载用户档案
      _userProfile = await _profileRepo.get();

      // 加载所有作品、声音、明信片
      _works = await _workRepo.getAll();
      _sounds = await _soundRepo.getAll();
      _cards = await _cardRepo.getAll();

      // 根据数据重新计算音乐树状态
      _treeData = _buildTreeData();
    } catch (e) {
      debugPrint('[AppState] 加载本地数据失败: $e');
      _loadError = '数据加载失败，请检查存储空间后重启应用：$e';
      // 即使加载失败也标记为已完成，避免反复重试
    }

    _dataLoaded = true;
    notifyListeners();
  }

  /// 从现有数据构建音乐树数据。
  MusicTreeData _buildTreeData() {
    final now = DateTime.now();
    final lastActive =
        _works.isNotEmpty ? _works.first.createdAt : now;

    // 累计使用天数
    final activeDays = <String>{};
    for (final w in _works) {
      activeDays.add('${w.createdAt.year}-${w.createdAt.month}-${w.createdAt.day}');
    }
    final totalDays = activeDays.length;

    // 连续使用天数
    int streakDays = 0;
    for (int i = 0; i < 365; i++) {
      final check = now.subtract(Duration(days: i));
      final key = '${check.year}-${check.month}-${check.day}';
      if (activeDays.contains(key)) {
        streakDays++;
      } else {
        break;
      }
    }

    final sharedCards = _cards.where((c) => c.direction == VoiceCardDirection.sent).length;
    final receivedReplies = _cards.where((c) => c.direction == VoiceCardDirection.received).length;

    // 综合成长能量
    final workEnergy = (_works.length * 15).clamp(0, 55).toDouble();
    final streakEnergy = (streakDays * 5).clamp(0, 25).toDouble();
    final cardEnergy = (sharedCards * 3).clamp(0, 10).toDouble();
    final replyEnergy = (receivedReplies * 5).clamp(0, 10).toDouble();
    final growthEnergy = (workEnergy + streakEnergy + cardEnergy + replyEnergy).clamp(0, 100).toDouble();

    final data = MusicTreeData(
      totalWorks: _works.length,
      streakDays: streakDays,
      totalDays: totalDays,
      sharedCards: sharedCards,
      receivedReplies: receivedReplies,
      growthEnergy: growthEnergy,
      lastActiveDate: lastActive,
    );

    return data.copyWith(
      treeState: MusicTreeData.calculateState(data),
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
    // 内存去重：如果已存在同 ID 作品，先移除旧的
    _works.removeWhere((w) => w.id == work.id);
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
    } else {
      // 作品不在内存中，从数据库重新加载
      _works = await _workRepo.getAll();
    }
    notifyListeners();
  }

  /// 删除作品（同时删除数据库记录 + 关联磁盘文件）。
  Future<void> deleteWork(String id) async {
    // 先获取要删除的作品信息，用于清理关联文件
    final work = _works.where((w) => w.id == id).firstOrNull;
    if (!kIsWeb) await _workRepo.delete(id);

    // 清理关联的磁盘文件，防止存储泄漏
    if (work != null && !kIsWeb) {
      final storage = FileStorageService();
      // 忽略文件不存在的错误
      try { await storage.deleteFile(work.audioPath); } catch (_) {}
      if (work.coverPath != null) {
        try { await storage.deleteFile(work.coverPath!); } catch (_) {}
      }
    }

    _works.removeWhere((w) => w.id == id);
    _updateTree();
    notifyListeners();
  }

  /// 切换作品私密状态。
  Future<void> togglePrivate(String id) async {
    if (!kIsWeb) await _workRepo.togglePrivate(id);
    final index = _works.indexWhere((w) => w.id == id);
    if (index != -1) {
      _works[index] = _works[index].copyWith(
        isPrivate: !_works[index].isPrivate,
      );
    }
    notifyListeners();
  }

  /// 非私密作品（公开作品列表）。
  List<MusicWork> get publicWorks =>
      _works.where((w) => !w.isPrivate).toList();

  /// 私密作品列表（需密码访问）。
  List<MusicWork> get privateWorks =>
      _works.where((w) => w.isPrivate).toList();

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
    final index = _cards.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cards[index] = _cards[index].copyWith(readAt: DateTime.now());
    }
    notifyListeners();
  }

  Future<void> deleteVoiceCard(String id) async {
    if (!kIsWeb) await _cardRepo.delete(id);
    _cards.removeWhere((c) => c.id == id);
    _updateTree();
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
