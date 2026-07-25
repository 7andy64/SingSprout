import '../models/music_work.dart';
import 'local_storage_service.dart';

/// 作品仓库 — 本地持久化 MusicWork 列表
///
/// 独立于 HummingGardenProvider 的内存状态，
/// 作为音乐树等模块的持久化数据源。
class WorkRepository {
  static final WorkRepository _instance = WorkRepository._();
  factory WorkRepository() => _instance;
  WorkRepository._();

  static const _filename = 'works.json';

  final _storage = LocalStorageService();
  List<MusicWork>? _cache;

  /// 获取全部作品（带内存缓存）
  Future<List<MusicWork>> getWorks() async {
    if (_cache != null) return _cache!;
    final raw = await _storage.readList(_filename);
    _cache = raw.map((m) => MusicWork.fromJson(m)).toList();
    return _cache!;
  }

  /// 添加作品
  Future<void> addWork(MusicWork work) async {
    final works = await getWorks();
    works.insert(0, work);
    await _persist(works);
  }

  /// 删除作品
  Future<void> deleteWork(String id) async {
    final works = await getWorks();
    works.removeWhere((w) => w.id == id);
    await _persist(works);
  }

  /// 清空缓存（用于强制刷新）
  void clearCache() {
    _cache = null;
  }

  Future<void> _persist(List<MusicWork> works) async {
    _cache = works;
    await _storage.writeList(
      _filename,
      works.map((w) => w.toJson()).toList(),
    );
  }
}
