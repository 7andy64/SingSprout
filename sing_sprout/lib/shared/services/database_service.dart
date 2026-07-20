import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// SQLite 数据库服务
///
/// 管理数据库的创建、迁移和连接生命周期。
/// 所有表的设计遵循「离线优先」原则，本地为主、云端为辅。
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  static const _dbName = 'singsprout.db';
  static const _dbVersion = 1;

  Database? _db;

  /// 获取数据库实例（延迟初始化，首次调用时创建）。
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  // ── 初始化 ──

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE works (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        audio_path TEXT NOT NULL,
        cover_path TEXT,
        style_seed TEXT NOT NULL DEFAULT 'morningDew',
        mood_color TEXT,
        note TEXT,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_encrypted INTEGER NOT NULL DEFAULT 1,
        source_module TEXT NOT NULL DEFAULT 'humming_garden',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sound_samples (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        audio_path TEXT NOT NULL,
        type TEXT NOT NULL,
        bpm REAL,
        pitch_sequence TEXT,
        timbre_feature TEXT,
        recommended_use TEXT,
        is_public INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE voice_cards (
        id TEXT PRIMARY KEY,
        work_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        recipient_id TEXT,
        audio_path TEXT,
        text_content TEXT,
        cover_url TEXT,
        reply_to_id TEXT,
        direction TEXT NOT NULL DEFAULT 'sent',
        created_at TEXT NOT NULL,
        read_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        local_id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        voice_baseline_path TEXT NOT NULL DEFAULT '',
        guardian_animal TEXT NOT NULL DEFAULT 'panda',
        role TEXT NOT NULL DEFAULT 'student',
        has_completed_onboarding INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 索引：加速按时间排序和按模块查询
    await db.execute(
      'CREATE INDEX idx_works_created_at ON works(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_works_source_module ON works(source_module)',
    );
    await db.execute(
      'CREATE INDEX idx_works_favorite ON works(is_favorite)',
    );
    await db.execute(
      'CREATE INDEX idx_sound_samples_created_at ON sound_samples(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_voice_cards_created_at ON voice_cards(created_at DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本迁移在此追加
    debugPrint(
      '[DatabaseService] 数据库升级: v$oldVersion -> v$newVersion（暂无迁移）',
    );
  }

  // ── 工具方法 ──

  /// 清空所有表（用于重置/退出登录）。
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('works');
    await db.delete('sound_samples');
    await db.delete('voice_cards');
    await db.delete('user_profile');
  }

  /// 关闭数据库连接。
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
