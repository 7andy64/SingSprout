import 'package:sqflite/sqflite.dart';
import '../models/music_work.dart';
import '../services/database_service.dart';

/// 音乐作品仓库 — 管理作品的本地持久化
class WorkRepository {
  final DatabaseService _db = DatabaseService();

  // ── 创建 ──

  /// 保存新作品到本地数据库。
  Future<void> insert(MusicWork work) async {
    final db = await _db.database;
    await db.insert('works', work.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── 读取 ──

  /// 获取所有作品，按更新时间倒序排列。
  Future<List<MusicWork>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('works', orderBy: 'updated_at DESC');
    return rows.map((r) => MusicWork.fromJson(r)).toList();
  }

  /// 按来源模块筛选作品。
  Future<List<MusicWork>> getByModule(String sourceModule) async {
    final db = await _db.database;
    final rows = await db.query(
      'works',
      where: 'source_module = ?',
      whereArgs: [sourceModule],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => MusicWork.fromJson(r)).toList();
  }

  /// 获取收藏的作品。
  Future<List<MusicWork>> getFavorites() async {
    final db = await _db.database;
    final rows = await db.query(
      'works',
      where: 'is_favorite = 1',
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => MusicWork.fromJson(r)).toList();
  }

  /// 根据 ID 获取单个作品。
  Future<MusicWork?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('works', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MusicWork.fromJson(rows.first);
  }

  /// 获取作品总数。
  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM works');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 搜索作品（按标题模糊匹配）。
  Future<List<MusicWork>> search(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'works',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => MusicWork.fromJson(r)).toList();
  }

  // ── 更新 ──

  /// 更新作品（通过 copyWith 后的新对象保存）。
  Future<void> update(MusicWork work) async {
    final db = await _db.database;
    await db.update(
      'works',
      work.toJson(),
      where: 'id = ?',
      whereArgs: [work.id],
    );
  }

  /// 切换收藏状态。
  Future<void> toggleFavorite(String id) async {
    final work = await getById(id);
    if (work == null) return;
    await update(work.copyWith(isFavorite: !work.isFavorite));
  }

  // ── 删除 ──

  /// 删除单个作品。
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('works', where: 'id = ?', whereArgs: [id]);
  }

  /// 批量删除作品。
  Future<void> deleteAll(List<String> ids) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('works', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
