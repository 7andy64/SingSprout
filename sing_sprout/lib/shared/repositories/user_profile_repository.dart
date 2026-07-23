import 'package:sqflite/sqflite.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// 用户档案仓库 — 管理本地用户档案的单行记录
class UserProfileRepository {
  final DatabaseService _db = DatabaseService();

  // ── 保存 ──

  /// 保存用户档案（单条记录，存在则替换，避免 check-then-act 竞态条件）。
  Future<void> save(UserProfile profile) async {
    final db = await _db.database;
    await db.insert(
      'user_profile',
      _toRow(profile),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── 读取 ──

  /// 读取用户档案，不存在返回 null。
  Future<UserProfile?> get() async {
    final db = await _db.database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  // ── 删除 ──

  /// 删除当前用户档案。
  Future<void> delete() async {
    final db = await _db.database;
    await db.delete('user_profile');
  }

  // ── 更新 ──

  /// 更新引导完成状态。
  Future<void> setOnboardingCompleted(bool completed) async {
    final db = await _db.database;
    final profile = await get();
    if (profile == null) return;
    await db.update(
      'user_profile',
      {'has_completed_onboarding': completed ? 1 : 0},
      where: 'local_id = ?',
      whereArgs: [profile.localId],
    );
  }

  // ── 序列化辅助 ──

  Map<String, dynamic> _toRow(UserProfile p) => {
        'local_id': p.localId,
        'nickname': p.nickname,
        'voice_baseline_path': p.voiceBaselinePath,
        'guardian_animal': p.guardianAnimal.name,
        'role': p.role.name,
        'has_completed_onboarding': p.hasCompletedOnboarding ? 1 : 0,
        'created_at': p.createdAt.toIso8601String(),
      };

  UserProfile _fromRow(Map<String, dynamic> row) => UserProfile(
        localId: row['local_id'] as String,
        nickname: row['nickname'] as String,
        voiceBaselinePath: row['voice_baseline_path'] as String? ?? '',
        guardianAnimal: GuardianAnimal.values.firstWhere(
          (e) => e.name == row['guardian_animal'],
          orElse: () => GuardianAnimal.panda,
        ),
        role: UserRole.values.firstWhere(
          (e) => e.name == row['role'],
          orElse: () => UserRole.student,
        ),
        hasCompletedOnboarding:
            (row['has_completed_onboarding'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
