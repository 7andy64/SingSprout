import 'package:flutter/foundation.dart';
import '../../shared/models/music_work.dart';
import '../../shared/repositories/work_repository.dart';

/// 哼唱花园状态管理
///
/// TODO: 当前未注入 MultiProvider，计划在各页面接入 AppState 后启用此 Provider。
/// 届时将注册为 ChangeNotifierProvider 供 HummingGardenPage 使用。
class HummingGardenProvider extends ChangeNotifier {
  final WorkRepository _workRepo = WorkRepository();
  final List<MusicWork> _works = [];
  bool _isLoading = false;

  List<MusicWork> get works => List.unmodifiable(_works);
  bool get isLoading => _isLoading;

  /// 添加作品
  Future<void> addWork(MusicWork work) async {
    _works.insert(0, work);
    notifyListeners();
    await _workRepo.insert(work);
  }

  /// 删除作品
  Future<void> deleteWork(String id) async {
    _works.removeWhere((w) => w.id == id);
    notifyListeners();
    await _workRepo.delete(id);
  }

  /// 从本地数据库加载所有作品
  Future<void> loadWorks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _works.clear();
      _works.addAll(await _workRepo.getAll());
    } catch (e) {
      debugPrint('[HummingGardenProvider] 加载作品失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
