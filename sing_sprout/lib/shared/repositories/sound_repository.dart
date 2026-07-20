import 'package:sqflite/sqflite.dart';
import '../models/sound_sample.dart';
import '../services/database_service.dart';

/// 声音样本仓库 — 管理田野声音实验室采集的声音素材
class SoundRepository {
  final DatabaseService _db = DatabaseService();

  // ── 创建 ──

  Future<void> insert(SoundSample sample) async {
    final db = await _db.database;
    await db.insert('sound_samples', sample.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── 读取 ──

  Future<List<SoundSample>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('sound_samples', orderBy: 'created_at DESC');
    return rows.map((r) => SoundSample.fromJson(r)).toList();
  }

  Future<SoundSample?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('sound_samples', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SoundSample.fromJson(rows.first);
  }

  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM sound_samples');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── 更新 ──

  Future<void> update(SoundSample sample) async {
    final db = await _db.database;
    await db.update(
      'sound_samples',
      sample.toJson(),
      where: 'id = ?',
      whereArgs: [sample.id],
    );
  }

  // ── 删除 ──

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('sound_samples', where: 'id = ?', whereArgs: [id]);
  }
}
