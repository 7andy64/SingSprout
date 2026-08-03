import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/economy_models.dart';
import '../repositories/economy_repository.dart';

/// 金松果经济系统状态管理
///
/// 管理钱包余额、交易流水、背包库存、商店商品和每日挑战。
/// 设计原则：
/// - 离线优先，所有操作在本地完成
/// - 每日获取上限 100 颗金松果，自然限制刷币
/// - 不收集设备信息，不设防作弊技术
class EconomyProvider extends ChangeNotifier {
  final EconomyRepository _repo = EconomyRepository();

  // ── 状态 ──
  Wallet _wallet = const Wallet();
  List<Transaction> _transactions = [];
  List<ShopItem> _shopItems = [];
  List<InventoryItem> _inventory = [];
  DailyProgress? _todayProgress;
  bool _loaded = false;

  // ── Getters ──
  Wallet get wallet => _wallet;
  int get balance => _wallet.balance;
  int get todayEarned => _wallet.todayEarned;
  bool get isDailyLimitReached => _wallet.isDailyLimitReached;
  int get remainingToday => _wallet.remainingToday;
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<ShopItem> get shopItems => List.unmodifiable(_shopItems);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  DailyProgress? get todayProgress => _todayProgress;
  bool get loaded => _loaded;

  /// 已拥有的物品 ID 集合
  Set<String> get ownedItemIds => _inventory.map((i) => i.itemId).toSet();

  /// 当前已装备的物品 ID 集合
  Set<String> get equippedItemIds =>
      _inventory.where((i) => i.isEquipped).map((i) => i.itemId).toSet();

  /// 按分类获取已装备物品
  String? getEquippedItemId(ShopCategory category) {
    final shopIds = _shopItems
        .where((s) => s.category == category)
        .map((s) => s.id)
        .toSet();
    // 内置列表回退
    final allIds = shopIds.isNotEmpty
        ? shopIds
        : ShopItem.builtInItems
            .where((s) => s.category == category)
            .map((s) => s.id)
            .toSet();
    return _inventory
        .where((i) => i.isEquipped && allIds.contains(i.itemId))
        .map((i) => i.itemId)
        .firstOrNull;
  }

  /// 已装备的头像框 emoji（用于显示），没有则返回 null。
  String? get equippedAvatarFrameEmoji {
    final id = getEquippedItemId(ShopCategory.avatarFrame);
    if (id == null) return null;
    return ShopItem.builtInItems
        .where((s) => s.id == id)
        .map((s) => s.emoji)
        .firstOrNull;
  }

  /// 检查守护动物是否已拥有（或为默认熊猫）。
  bool isAnimalOwned(String guardianAnimalName) {
    // 默认熊猫始终拥有
    if (guardianAnimalName == 'panda') return true;
    // 映射：GuardianAnimal.name → shop item id
    final shopId = switch (guardianAnimalName) {
      'tit' => 'pet_blue_tit',
      'frog' => 'pet_rainbow_frog',
      'firefly' => 'pet_golden_firefly',
      _ => null,
    };
    if (shopId == null) return false;
    return ownedItemIds.contains(shopId);
  }

  // ═══════════════════════════════════════════════════════════
  // 初始化
  // ═══════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_loaded) return;

    try {
      await _loadWallet();
      await _loadTransactions();
      await _loadShopItems();
      await _loadInventory();
      _loaded = true;
    } catch (e) {
      debugPrint('[EconomyProvider] init failed: $e');
    }
    notifyListeners();
  }

  Future<void> _loadWallet() async {
    _wallet = await _repo.getWallet();
    // 检查是否需要跨天重置
    final today = EconomyRepository.todayStr;
    if (_wallet.lastResetDate != today) {
      await _repo.resetDaily(today);
      _wallet = _wallet.copyWith(todayEarned: 0, lastResetDate: today);
    }
    _todayProgress = await _repo.getTodayProgress(today);
  }

  Future<void> _loadTransactions() async {
    _transactions = await _repo.getTransactions();
  }

  Future<void> _loadShopItems() async {
    _shopItems = await _repo.getShopItems();
  }

  Future<void> _loadInventory() async {
    _inventory = await _repo.getInventory();
  }

  // ═══════════════════════════════════════════════════════════
  // 金松果获取
  // ═══════════════════════════════════════════════════════════

  /// 尝试获取金松果。
  /// 返回实际获得的金额（受每日上限限制）。
  /// 返回 0 表示已达每日上限。
  int earnCoins(int amount, TxType type, String description, {String? refId}) {
    // 跨天检查
    final today = EconomyRepository.todayStr;
    if (_wallet.lastResetDate != today) {
      _wallet = _wallet.copyWith(todayEarned: 0, lastResetDate: today);
    }

    // 每日上限检查
    if (_wallet.isDailyLimitReached) return 0;

    final actual = min(amount, _wallet.remainingToday);
    if (actual <= 0) return 0;

    final tx = Transaction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      type: type,
      amount: actual,
      description: description,
      refId: refId,
      timestamp: DateTime.now(),
    );

    _wallet = _wallet.copyWith(
      balance: _wallet.balance + actual,
      totalEarned: _wallet.totalEarned + actual,
      todayEarned: _wallet.todayEarned + actual,
    );

    _transactions.insert(0, tx);
    _persistEarn(tx);

    notifyListeners();
    return actual;
  }

  Future<void> _persistEarn(Transaction tx) async {
    await _repo.updateBalance(tx.amount);
    await _repo.addTransaction(tx);
    await _repo.addDailyEarnings(EconomyRepository.todayStr, tx.amount);
  }

  // ═══════════════════════════════════════════════════════════
  // 金松果消费
  // ═══════════════════════════════════════════════════════════

  /// 检查余额是否足够。
  bool canAfford(int price) => _wallet.balance >= price;

  /// 花费金松果（不涉及物品购买，纯消费）。
  bool spendCoins(int amount, String description) {
    if (!canAfford(amount)) return false;

    final tx = Transaction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      type: TxType.spendShop,
      amount: -amount,
      description: description,
      timestamp: DateTime.now(),
    );

    _wallet = _wallet.copyWith(balance: _wallet.balance - amount);
    _transactions.insert(0, tx);

    unawaited(_repo.updateBalance(-amount));
    unawaited(_repo.addTransaction(tx));

    notifyListeners();
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 商店购买
  // ═══════════════════════════════════════════════════════════

  /// 购买商店物品。返回 null 表示成功，返回错误信息表示失败。
  String? buyItem(ShopItem item) {
    if (ownedItemIds.contains(item.id)) return '你已经拥有这件物品啦';
    if (!canAfford(item.price)) return '金松果不够哦，再去玩玩游戏吧';

    final tx = Transaction(
      id: 'buy_${DateTime.now().millisecondsSinceEpoch}',
      type: TxType.spendShop,
      amount: -item.price,
      description: '兑换了「${item.name}」${item.emoji}',
      refId: item.id,
      timestamp: DateTime.now(),
    );

    final inventoryItem = InventoryItem(
      itemId: item.id,
      acquiredTime: DateTime.now(),
    );

    _wallet = _wallet.copyWith(balance: _wallet.balance - item.price);
    _transactions.insert(0, tx);
    _inventory.insert(0, inventoryItem);

    _persistPurchase(tx, inventoryItem);

    notifyListeners();
    return null; // 成功
  }

  Future<void> _persistPurchase(Transaction tx, InventoryItem item) async {
    await _repo.updateBalance(tx.amount);
    await _repo.addTransaction(tx);
    await _repo.addToInventory(item);
  }

  // ═══════════════════════════════════════════════════════════
  // 装备 / 卸下
  // ═══════════════════════════════════════════════════════════

  Future<void> equipItem(String itemId) async {
    // 从商店物品列表中找分类（已加载 + 内置回退）
    ShopItem? shopItem = _shopItems.where((s) => s.id == itemId).firstOrNull;
    shopItem ??= ShopItem.builtInItems.where((s) => s.id == itemId).firstOrNull;
    if (shopItem == null) {
      debugPrint('[Economy] equipItem: item $itemId not found');
      return;
    }

    await _repo.unequipCategory(shopItem.category.code);
    await _repo.setEquipped(itemId, true);
    await _loadInventory();
    notifyListeners();
  }

  Future<void> unequipItem(String itemId) async {
    await _repo.setEquipped(itemId, false);
    await _loadInventory();
    notifyListeners();
  }

  /// 切换装备状态。
  Future<void> toggleEquip(String itemId) async {
    final inv = _inventory.where((i) => i.itemId == itemId).firstOrNull;
    if (inv == null) return;
    if (inv.isEquipped) {
      await unequipItem(itemId);
    } else {
      await equipItem(itemId);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 每日挑战
  // ═══════════════════════════════════════════════════════════

  bool get dailyChallengeCompleted =>
      _todayProgress?.dailyChallengeCompleted ?? false;

  Future<void> completeDailyChallenge() async {
    final today = EconomyRepository.todayStr;
    _todayProgress = DailyProgress(date: today, dailyChallengeCompleted: true,
        dailyEarnings: _todayProgress?.dailyEarnings ?? 0);
    await _repo.upsertDailyProgress(_todayProgress!);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 声音收集奖励（与田野声景实验室联动）
  // ═══════════════════════════════════════════════════════════

  /// 识别到新类型声音时调用，发放金松果奖励。
  int rewardSoundCollection(String soundType) {
    return earnCoins(3, TxType.earnCollect, '收集到声音：$soundType');
  }
}
