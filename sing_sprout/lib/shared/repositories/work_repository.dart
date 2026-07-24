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
    // 转义 LIKE 通配符，防止用户输入 % 或 _ 改变搜索语义
    final escaped = query.replaceAll('%', r'\%').replaceAll('_', r'\_');
    final rows = await db.query(
      'works',
      where: 'title LIKE ?',
      whereArgs: ['%$escaped%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => MusicWork.fromJson(r)).toList();
  }

  // ── 更新 ──

  /// 更新作品（通过 copyWith 后的新对象保存），不覆盖创建时间。
  Future<void> update(MusicWork work) async {
    final db = await _db.database;
    final row = work.toJson();
    row.remove('created_at'); // 创建时间不可修改
    await db.update(
      'works',
      row,
      where: 'id = ?',
      whereArgs: [work.id],
    );
  }

  /// 切换私密状态。
  Future<void> togglePrivate(String id) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE works SET is_private = 1 - is_private, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// 切换收藏状态（原子操作，避免并发丢失更新）。
  Future<void> toggleFavorite(String id) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE works SET is_favorite = 1 - is_favorite, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
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
