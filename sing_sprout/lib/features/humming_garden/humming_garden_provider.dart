import 'package:flutter/foundation.dart';
import '../../shared/models/music_work.dart';
import '../../shared/repositories/work_repository.dart';

/// 哼唱花园状态管理
class HummingGardenProvider extends ChangeNotifier {
  final WorkRepository _workRepo = WorkRepository();
  final List<MusicWork> _works = [];
  bool _isLoading = false;

  List<MusicWork> get works => List.unmodifiable(_works);
  bool get isLoading => _isLoading;

  /// 添加作品
  void addWork(MusicWork work) {
    _works.insert(0, work);
    _workRepo.insert(work);
    notifyListeners();
  }

  /// 删除作品
  void deleteWork(String id) {
    _works.removeWhere((w) => w.id == id);
    _workRepo.delete(id);
    notifyListeners();
  }

  /// 从本地数据库加载所有作品
  Future<void> loadWorks() async {
    _isLoading = true;
    notifyListeners();

    _works.clear();
    _works.addAll(await _workRepo.getAll());

    _isLoading = false;
    notifyListeners();
  }
}
