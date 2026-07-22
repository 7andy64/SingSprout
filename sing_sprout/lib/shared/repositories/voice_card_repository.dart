import 'package:sqflite/sqflite.dart';
import '../models/voice_card.dart';
import '../services/database_service.dart';

/// 声音明信片仓库 — 管理声音邮局的明信片收发记录
class VoiceCardRepository {
  final DatabaseService _db = DatabaseService();

  // ── 创建 ──

  Future<void> insert(VoiceCard card) async {
    final db = await _db.database;
    await db.insert('voice_cards', _toRow(card),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── 读取 ──

  /// 获取所有发出的明信片。
  Future<List<VoiceCard>> getSent() async {
    final db = await _db.database;
    final rows = await db.query(
      'voice_cards',
      where: 'direction = ?',
      whereArgs: ['sent'],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 获取所有收到的明信片（回信）。
  Future<List<VoiceCard>> getReceived() async {
    final db = await _db.database;
    final rows = await db.query(
      'voice_cards',
      where: 'direction = ?',
      whereArgs: ['received'],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 获取所有明信片（收发混合，时间倒序）。
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

  /// 按 ID 查询单张明信片。
  Future<VoiceCard?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('voice_cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// 获取某作品关联的所有明信片。
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

  /// 获取所有未读明信片。
  Future<List<VoiceCard>> getUnread() async {
    final db = await _db.database;
    final rows = await db.query(
      'voice_cards',
      where: 'read_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  // ── 更新 ──

  /// 标记明信片为已读。
  Future<void> markAsRead(String id) async {
    final db = await _db.database;
    await db.update(
      'voice_cards',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
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
        'reply_to_id': card.replyToId,
        'direction': card.direction.name,
        'created_at': card.createdAt.toIso8601String(),
        'read_at': card.readAt?.toIso8601String(),
      };

  VoiceCard _fromRow(Map<String, dynamic> row) => VoiceCard(
        id: row['id'] as String,
        workId: row['work_id'] as String,
        senderId: row['sender_id'] as String,
        recipientId: row['recipient_id'] as String?,
        audioPath: row['audio_path'] as String?,
        textContent: row['text_content'] as String?,
        coverUrl: row['cover_url'] as String?,
        replyToId: row['reply_to_id'] as String?,
        direction: VoiceCardDirection.values.firstWhere(
          (e) => e.name == row['direction'],
          orElse: () => VoiceCardDirection.sent,
        ),
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] != null
            ? DateTime.parse(row['read_at'] as String)
            : null,
      );
}
