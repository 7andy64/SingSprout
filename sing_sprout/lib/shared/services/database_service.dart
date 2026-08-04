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
  static const _dbVersion = 4;

  Database? _db;
  Future<Database>? _dbFuture;

  /// 获取数据库实例（延迟初始化，首次调用时创建）。
  /// 使用 Future 哨兵避免并发调用产生竞态条件。
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _dbFuture ??= _initDatabase();
    _db = await _dbFuture;
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
    await db.execute('PRAGMA foreign_keys = ON');

    await db.transaction((txn) async {
      await txn.execute('''
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
          is_private INTEGER NOT NULL DEFAULT 0,
          source_module TEXT NOT NULL DEFAULT 'humming_garden',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await txn.execute('''
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

      await txn.execute('''
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
          greeting_audio_path TEXT,
          greeting_text TEXT,
          created_at TEXT NOT NULL,
          read_at TEXT
        )
      ''');

      await txn.execute('''
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
      await txn.execute(
        'CREATE INDEX idx_works_created_at ON works(created_at DESC)',
      );
      await txn.execute(
        'CREATE INDEX idx_works_source_module ON works(source_module)',
      );
      await txn.execute(
        'CREATE INDEX idx_works_favorite ON works(is_favorite)',
      );
      await txn.execute(
        'CREATE INDEX idx_sound_samples_created_at ON sound_samples(created_at DESC)',
      );
      await txn.execute(
        'CREATE INDEX idx_voice_cards_created_at ON voice_cards(created_at DESC)',
      );
      await txn.execute(
        'CREATE INDEX idx_voice_cards_work_id ON voice_cards(work_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_voice_cards_read_at ON voice_cards(read_at)',
      );
      await txn.execute(
        'CREATE INDEX idx_voice_cards_direction ON voice_cards(direction)',
      );

      // v4 金松果经济系统
      await txn.execute('''
        CREATE TABLE wallet (
          id INTEGER PRIMARY KEY DEFAULT 1,
          balance INTEGER NOT NULL DEFAULT 0,
          total_earned INTEGER NOT NULL DEFAULT 0,
          today_earned INTEGER NOT NULL DEFAULT 0,
          last_reset_date TEXT NOT NULL DEFAULT ''
        )
      ''');
      await txn.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          ref_id TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_transactions_timestamp ON transactions(timestamp DESC)',
      );

      await txn.execute('''
        CREATE TABLE shop_items (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          name TEXT NOT NULL,
          emoji TEXT NOT NULL DEFAULT '🎁',
          price INTEGER NOT NULL,
          asset_path TEXT,
          unlock_tree_level INTEGER NOT NULL DEFAULT 0
        )
      ''');
      // 插入内置商品
      for (final item in [
        {'id': 'frame_spring', 'category': 'avatar_frame', 'name': '春花框', 'emoji': '🌸', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'frame_star', 'category': 'avatar_frame', 'name': '星星框', 'emoji': '⭐', 'price': 30, 'unlock_tree_level': 0},
        {'id': 'frame_rainbow', 'category': 'avatar_frame', 'name': '彩虹框', 'emoji': '🌈', 'price': 50, 'unlock_tree_level': 3},
        {'id': 'frame_moon', 'category': 'avatar_frame', 'name': '月亮框', 'emoji': '🌙', 'price': 40, 'unlock_tree_level': 0},
        {'id': 'pet_golden_panda', 'category': 'pet_skin', 'name': '金熊猫', 'emoji': '🐼✨', 'price': 60, 'unlock_tree_level': 2},
        {'id': 'pet_blue_tit', 'category': 'pet_skin', 'name': '蓝羽山雀', 'emoji': '🐦💙', 'price': 40, 'unlock_tree_level': 0},
        {'id': 'pet_rainbow_frog', 'category': 'pet_skin', 'name': '彩虹蛙', 'emoji': '🐸🌈', 'price': 50, 'unlock_tree_level': 0},
        {'id': 'pet_golden_firefly', 'category': 'pet_skin', 'name': '金瓢虫', 'emoji': '🐞💛', 'price': 70, 'unlock_tree_level': 4},
        {'id': 'pet_golden_dog', 'category': 'pet_skin', 'name': '金毛小黄狗', 'emoji': '🐶💛', 'price': 60, 'unlock_tree_level': 3},
        {'id': 'pet_silver_cat', 'category': 'pet_skin', 'name': '银灰小花猫', 'emoji': '🐱🩶', 'price': 55, 'unlock_tree_level': 3},
        {'id': 'pet_yellow_duck', 'category': 'pet_skin', 'name': '黄绒小鸭子', 'emoji': '🦆💛', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_white_goat', 'category': 'pet_skin', 'name': '雪白小山羊', 'emoji': '🐐🤍', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_magic_elf', 'category': 'pet_skin', 'name': '魔法小精灵', 'emoji': '🧚✨', 'price': 80, 'unlock_tree_level': 5},
        {'id': 'pet_wise_elephant', 'category': 'pet_skin', 'name': '智慧小象', 'emoji': '🐘🧠', 'price': 70, 'unlock_tree_level': 4},
        {'id': 'pet_cunning_fox', 'category': 'pet_skin', 'name': '赤焰小狐狸', 'emoji': '🦊🔥', 'price': 65, 'unlock_tree_level': 3},
        {'id': 'pet_gentle_hedgehog', 'category': 'pet_skin', 'name': '温柔小刺猬', 'emoji': '🦔🌸', 'price': 55, 'unlock_tree_level': 2},
        {'id': 'pet_graceful_deer', 'category': 'pet_skin', 'name': '斑点小花鹿', 'emoji': '🦌🌿', 'price': 65, 'unlock_tree_level': 3},
        {'id': 'pet_lively_squirrel', 'category': 'pet_skin', 'name': '活泼小松鼠', 'emoji': '🐿️🌰', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_soft_rabbit', 'category': 'pet_skin', 'name': '软萌小兔子', 'emoji': '🐰🎀', 'price': 55, 'unlock_tree_level': 3},
        {'id': 'deco_bell', 'category': 'tree_deco', 'name': '风铃', 'emoji': '🎐', 'price': 15, 'unlock_tree_level': 0},
        {'id': 'deco_star', 'category': 'tree_deco', 'name': '小星星', 'emoji': '🌟', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'deco_fruit', 'category': 'tree_deco', 'name': '红果实', 'emoji': '🍎', 'price': 25, 'unlock_tree_level': 0},
        {'id': 'deco_lantern', 'category': 'tree_deco', 'name': '小灯笼', 'emoji': '🏮', 'price': 30, 'unlock_tree_level': 2},
        {'id': 'deco_heart', 'category': 'tree_deco', 'name': '爱心果', 'emoji': '💝', 'price': 35, 'unlock_tree_level': 3},
        {'id': 'card_forest', 'category': 'postcard_bg', 'name': '森林信纸', 'emoji': '🌿', 'price': 15, 'unlock_tree_level': 0},
        {'id': 'card_ocean', 'category': 'postcard_bg', 'name': '海洋信纸', 'emoji': '🌊', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'card_sunset', 'category': 'postcard_bg', 'name': '晚霞信纸', 'emoji': '🌅', 'price': 25, 'unlock_tree_level': 0},
        {'id': 'card_night', 'category': 'postcard_bg', 'name': '星空信纸', 'emoji': '🌌', 'price': 30, 'unlock_tree_level': 2},
        {'id': 'inst_flute', 'category': 'instrument', 'name': '笛子音色', 'emoji': '🪈', 'price': 80, 'unlock_tree_level': 3},
        {'id': 'inst_harp', 'category': 'instrument', 'name': '竖琴音色', 'emoji': '🎵', 'price': 100, 'unlock_tree_level': 4},
        {'id': 'inst_bell', 'category': 'instrument', 'name': '钟琴音色', 'emoji': '🔔', 'price': 90, 'unlock_tree_level': 3},
      ]) {
        await txn.insert('shop_items', {
          'id': item['id'],
          'category': item['category'],
          'name': item['name'],
          'emoji': item['emoji'],
          'price': item['price'],
          'asset_path': null,
          'unlock_tree_level': item['unlock_tree_level'],
        });
      }

      await txn.execute('''
        CREATE TABLE inventory (
          item_id TEXT PRIMARY KEY,
          quantity INTEGER NOT NULL DEFAULT 1,
          is_equipped INTEGER NOT NULL DEFAULT 0,
          acquired_time TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE daily_progress (
          date TEXT PRIMARY KEY,
          daily_challenge_completed INTEGER NOT NULL DEFAULT 0,
          daily_earnings INTEGER NOT NULL DEFAULT 0
        )
      ''');
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DatabaseService] 数据库升级: v$oldVersion -> v$newVersion');
    if (oldVersion < 2) {
      // v1 → v2: 添加私密作品字段
      await db.execute(
        'ALTER TABLE works ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // v2 → v3: 明信片语音祝福
      await db.execute(
        'ALTER TABLE voice_cards ADD COLUMN greeting_audio_path TEXT',
      );
      await db.execute(
        'ALTER TABLE voice_cards ADD COLUMN greeting_text TEXT',
      );
    }
    if (oldVersion < 4) {
      // v3 → v4: 金松果经济系统
      await db.execute('''
        CREATE TABLE wallet (
          id INTEGER PRIMARY KEY DEFAULT 1,
          balance INTEGER NOT NULL DEFAULT 0,
          total_earned INTEGER NOT NULL DEFAULT 0,
          today_earned INTEGER NOT NULL DEFAULT 0,
          last_reset_date TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          ref_id TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_transactions_timestamp ON transactions(timestamp DESC)',
      );
      await db.execute('''
        CREATE TABLE shop_items (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          name TEXT NOT NULL,
          emoji TEXT NOT NULL DEFAULT '🎁',
          price INTEGER NOT NULL,
          asset_path TEXT,
          unlock_tree_level INTEGER NOT NULL DEFAULT 0
        )
      ''');
      // 插入内置商品
      final items = [
        {'id': 'frame_spring', 'category': 'avatar_frame', 'name': '春花框', 'emoji': '🌸', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'frame_star', 'category': 'avatar_frame', 'name': '星星框', 'emoji': '⭐', 'price': 30, 'unlock_tree_level': 0},
        {'id': 'frame_rainbow', 'category': 'avatar_frame', 'name': '彩虹框', 'emoji': '🌈', 'price': 50, 'unlock_tree_level': 3},
        {'id': 'frame_moon', 'category': 'avatar_frame', 'name': '月亮框', 'emoji': '🌙', 'price': 40, 'unlock_tree_level': 0},
        {'id': 'pet_golden_panda', 'category': 'pet_skin', 'name': '金熊猫', 'emoji': '🐼✨', 'price': 60, 'unlock_tree_level': 2},
        {'id': 'pet_blue_tit', 'category': 'pet_skin', 'name': '蓝羽山雀', 'emoji': '🐦💙', 'price': 40, 'unlock_tree_level': 0},
        {'id': 'pet_rainbow_frog', 'category': 'pet_skin', 'name': '彩虹蛙', 'emoji': '🐸🌈', 'price': 50, 'unlock_tree_level': 0},
        {'id': 'pet_golden_firefly', 'category': 'pet_skin', 'name': '金瓢虫', 'emoji': '🐞💛', 'price': 70, 'unlock_tree_level': 4},
        {'id': 'pet_golden_dog', 'category': 'pet_skin', 'name': '金毛小黄狗', 'emoji': '🐶💛', 'price': 60, 'unlock_tree_level': 3},
        {'id': 'pet_silver_cat', 'category': 'pet_skin', 'name': '银灰小花猫', 'emoji': '🐱🩶', 'price': 55, 'unlock_tree_level': 3},
        {'id': 'pet_yellow_duck', 'category': 'pet_skin', 'name': '黄绒小鸭子', 'emoji': '🦆💛', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_white_goat', 'category': 'pet_skin', 'name': '雪白小山羊', 'emoji': '🐐🤍', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_magic_elf', 'category': 'pet_skin', 'name': '魔法小精灵', 'emoji': '🧚✨', 'price': 80, 'unlock_tree_level': 5},
        {'id': 'pet_wise_elephant', 'category': 'pet_skin', 'name': '智慧小象', 'emoji': '🐘🧠', 'price': 70, 'unlock_tree_level': 4},
        {'id': 'pet_cunning_fox', 'category': 'pet_skin', 'name': '赤焰小狐狸', 'emoji': '🦊🔥', 'price': 65, 'unlock_tree_level': 3},
        {'id': 'pet_gentle_hedgehog', 'category': 'pet_skin', 'name': '温柔小刺猬', 'emoji': '🦔🌸', 'price': 55, 'unlock_tree_level': 2},
        {'id': 'pet_graceful_deer', 'category': 'pet_skin', 'name': '斑点小花鹿', 'emoji': '🦌🌿', 'price': 65, 'unlock_tree_level': 3},
        {'id': 'pet_lively_squirrel', 'category': 'pet_skin', 'name': '活泼小松鼠', 'emoji': '🐿️🌰', 'price': 50, 'unlock_tree_level': 2},
        {'id': 'pet_soft_rabbit', 'category': 'pet_skin', 'name': '软萌小兔子', 'emoji': '🐰🎀', 'price': 55, 'unlock_tree_level': 3},
        {'id': 'deco_bell', 'category': 'tree_deco', 'name': '风铃', 'emoji': '🎐', 'price': 15, 'unlock_tree_level': 0},
        {'id': 'deco_star', 'category': 'tree_deco', 'name': '小星星', 'emoji': '🌟', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'deco_fruit', 'category': 'tree_deco', 'name': '红果实', 'emoji': '🍎', 'price': 25, 'unlock_tree_level': 0},
        {'id': 'deco_lantern', 'category': 'tree_deco', 'name': '小灯笼', 'emoji': '🏮', 'price': 30, 'unlock_tree_level': 2},
        {'id': 'deco_heart', 'category': 'tree_deco', 'name': '爱心果', 'emoji': '💝', 'price': 35, 'unlock_tree_level': 3},
        {'id': 'card_forest', 'category': 'postcard_bg', 'name': '森林信纸', 'emoji': '🌿', 'price': 15, 'unlock_tree_level': 0},
        {'id': 'card_ocean', 'category': 'postcard_bg', 'name': '海洋信纸', 'emoji': '🌊', 'price': 20, 'unlock_tree_level': 0},
        {'id': 'card_sunset', 'category': 'postcard_bg', 'name': '晚霞信纸', 'emoji': '🌅', 'price': 25, 'unlock_tree_level': 0},
        {'id': 'card_night', 'category': 'postcard_bg', 'name': '星空信纸', 'emoji': '🌌', 'price': 30, 'unlock_tree_level': 2},
        {'id': 'inst_flute', 'category': 'instrument', 'name': '笛子音色', 'emoji': '🪈', 'price': 80, 'unlock_tree_level': 3},
        {'id': 'inst_harp', 'category': 'instrument', 'name': '竖琴音色', 'emoji': '🎵', 'price': 100, 'unlock_tree_level': 4},
        {'id': 'inst_bell', 'category': 'instrument', 'name': '钟琴音色', 'emoji': '🔔', 'price': 90, 'unlock_tree_level': 3},
      ];
      for (final item in items) {
        await db.insert('shop_items', {
          'id': item['id'],
          'category': item['category'],
          'name': item['name'],
          'emoji': item['emoji'],
          'price': item['price'],
          'asset_path': null,
          'unlock_tree_level': item['unlock_tree_level'],
        });
      }
      await db.execute('''
        CREATE TABLE inventory (
          item_id TEXT PRIMARY KEY,
          quantity INTEGER NOT NULL DEFAULT 1,
          is_equipped INTEGER NOT NULL DEFAULT 0,
          acquired_time TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE daily_progress (
          date TEXT PRIMARY KEY,
          daily_challenge_completed INTEGER NOT NULL DEFAULT 0,
          daily_earnings INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  // ── 工具方法 ──

  /// 清空所有表（用于重置/退出登录）。
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('works');
      await txn.delete('sound_samples');
      await txn.delete('voice_cards');
      await txn.delete('user_profile');
    });
  }

  /// 关闭数据库连接。
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbFuture = null;
    }
  }
}
