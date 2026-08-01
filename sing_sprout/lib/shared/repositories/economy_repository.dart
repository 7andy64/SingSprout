import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/economy_models.dart';
import '../services/database_service.dart';

/// 金松果经济系统仓库
///
/// 管理钱包、交易流水、商店商品、背包库存和每日进度的本地持久化。
/// 所有数据存储在本地 SQLite，无需网络即可完整运行。
class EconomyRepository {
  final DatabaseService _db = DatabaseService();

  // ═══════════════════════════════════════════════════════════
  // 钱包
  // ═══════════════════════════════════════════════════════════

  Future<Wallet> getWallet() async {
    final db = await _db.database;
    final rows = await db.query('wallet', where: 'id = 1');
    if (rows.isEmpty) {
      await db.insert('wallet', {
        'id': 1,
        'balance': 0,
        'total_earned': 0,
        'today_earned': 0,
        'last_reset_date': '',
      });
      return const Wallet();
    }
    return Wallet.fromJson(rows.first);
  }

  /// 更新钱包余额（正数为增加，负数为减少）。
  /// 同时更新 today_earned 和 total_earned。
  Future<Wallet> updateBalance(int amount) async {
    final db = await _db.database;
    final wallet = await getWallet();

    final newBalance = wallet.balance + amount;
    final newTodayEarned = amount > 0 ? wallet.todayEarned + amount : wallet.todayEarned;
    final newTotalEarned = amount > 0 ? wallet.totalEarned + amount : wallet.totalEarned;

    await db.update(
      'wallet',
      {
        'balance': newBalance,
        'total_earned': newTotalEarned,
        'today_earned': newTodayEarned,
        'last_reset_date': wallet.lastResetDate,
      },
      where: 'id = 1',
    );

    return wallet.copyWith(
      balance: newBalance,
      totalEarned: newTotalEarned,
      todayEarned: newTodayEarned,
    );
  }

  /// 每日重置：将 today_earned 归零。
  Future<void> resetDaily(String today) async {
    final db = await _db.database;
    await db.update(
      'wallet',
      {'today_earned': 0, 'last_reset_date': today},
      where: 'id = 1',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 交易流水
  // ═══════════════════════════════════════════════════════════

  Future<void> addTransaction(Transaction tx) async {
    final db = await _db.database;
    await db.insert('transactions', tx.toJson());
  }

  Future<List<Transaction>> getTransactions({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((r) => Transaction.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 商店商品
  // ═══════════════════════════════════════════════════════════

  Future<List<ShopItem>> getShopItems() async {
    final db = await _db.database;
    final rows = await db.query('shop_items');
    if (rows.isEmpty) return ShopItem.builtInItems;
    return rows.map((r) => ShopItem.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 背包
  // ═══════════════════════════════════════════════════════════

  Future<List<InventoryItem>> getInventory() async {
    final db = await _db.database;
    final rows = await db.query('inventory', orderBy: 'acquired_time DESC');
    return rows.map((r) => InventoryItem.fromJson(r)).toList();
  }

  /// 获取已装备的物品列表。
  Future<List<InventoryItem>> getEquipped() async {
    final db = await _db.database;
    final rows = await db.query('inventory', where: 'is_equipped = 1');
    return rows.map((r) => InventoryItem.fromJson(r)).toList();
  }

  Future<void> addToInventory(InventoryItem item) async {
    final db = await _db.database;
    await db.insert('inventory', item.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 如果已有同 category 的已装备物品，先卸下再装备新的。
  Future<void> equipItem(String itemId, ShopCategory category) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // 卸下同类别所有物品
      final catCode = category.code;
      // 获取同类别已装备物品
      final catItems = await txn.rawQuery(
        '''SELECT inv.item_id FROM inventory inv
           INNER JOIN shop_items si ON inv.item_id = si.id
           WHERE inv.is_equipped = 1 AND si.category = ?''',
        [catCode],
      );
      for (final row in catItems) {
        await txn.update(
          'inventory',
          {'is_equipped': 0},
          where: 'item_id = ?',
          whereArgs: [row['item_id']],
        );
      }
      // 装备目标物品
      await txn.update(
        'inventory',
        {'is_equipped': 1},
        where: 'item_id = ?',
        whereArgs: [itemId],
      );
    });
  }

  Future<void> unequipItem(String itemId) async {
    final db = await _db.database;
    await db.update(
      'inventory',
      {'is_equipped': 0},
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  /// 检查是否拥有某物品。
  Future<bool> hasItem(String itemId) async {
    final db = await _db.database;
    final rows = await db.query('inventory', where: 'item_id = ?', whereArgs: [itemId]);
    return rows.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════
  // 每日进度
  // ═══════════════════════════════════════════════════════════

  Future<DailyProgress?> getTodayProgress(String today) async {
    final db = await _db.database;
    final rows = await db.query('daily_progress', where: 'date = ?', whereArgs: [today]);
    if (rows.isEmpty) return null;
    return DailyProgress.fromJson(rows.first);
  }

  Future<void> upsertDailyProgress(DailyProgress progress) async {
    final db = await _db.database;
    await db.insert('daily_progress', progress.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 记录每日收益（累加）。
  Future<void> addDailyEarnings(String today, int amount) async {
    final db = await _db.database;
    final existing = await getTodayProgress(today);
    if (existing != null) {
      await db.rawUpdate(
        'UPDATE daily_progress SET daily_earnings = daily_earnings + ? WHERE date = ?',
        [amount, today],
      );
    } else {
      await db.insert('daily_progress', DailyProgress(
        date: today,
        dailyEarnings: amount,
      ).toJson());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 便捷方法
  // ═══════════════════════════════════════════════════════════

  /// 获取当前日期的 'YYYY-MM-DD' 字符串。
  static String get todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
