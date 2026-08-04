import 'package:sqflite/sqflite.dart';
import '../models/voice_card.dart';
import '../services/database_service.dart';

/// 声音明信片仓库 — 管理声音邮局的发件箱记录
class VoiceCardRepository {
  final DatabaseService _db = DatabaseService();

  // ── 创建 ──

  Future<void> insert(VoiceCard card) async {
    final db = await _db.database;
    await db.insert('voice_cards', _toRow(card),
        conflictAlgorithm: ConflictAlgorithm.replace,);
  }

  // ── 读取 ──

  Future<List<VoiceCard>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('voice_cards', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM voice_cards');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<VoiceCard?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('voice_cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<VoiceCard>> getByWorkId(String workId) async {
    final db = await _db.database;
    final rows = await db.query(
      'voice_cards',
      where: 'work_id = ?',
      whereArgs: [workId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  // ── 删除 ──

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('voice_cards', where: 'id = ?', whereArgs: [id]);
  }

  // ── 序列化辅助 ──

  Map<String, dynamic> _toRow(VoiceCard card) => {
        'id': card.id,
        'work_id': card.workId,
        'sender_id': card.senderId,
        'recipient_id': card.recipientId,
        'audio_path': card.audioPath,
        'text_content': card.textContent,
        'cover_url': card.coverUrl,
        'greeting_audio_path': card.greetingAudioPath,
        'greeting_text': card.greetingText,
        'created_at': card.createdAt.toIso8601String(),
      };

  VoiceCard _fromRow(Map<String, dynamic> row) => VoiceCard(
        id: row['id'] as String,
        workId: row['work_id'] as String,
        senderId: row['sender_id'] as String,
        recipientId: row['recipient_id'] as String?,
        audioPath: row['audio_path'] as String?,
        textContent: row['text_content'] as String?,
        coverUrl: row['cover_url'] as String?,
        greetingAudioPath: row['greeting_audio_path'] as String?,
        greetingText: row['greeting_text'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
