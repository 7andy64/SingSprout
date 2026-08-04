/// 金松果经济系统数据模型
///
/// 设计原则：
/// - 所有数据默认本地存储，无需联网
/// - 不收集设备指纹、不做技术防作弊
/// - 通过每日获取上限自然限制刷币行为
/// - 简单、透明、孩子能理解

// ── 钱包 ──

class Wallet {
  final int balance;
  final int totalEarned;
  final int todayEarned;
  final String lastResetDate; // 'YYYY-MM-DD'，用于跨天重置今日获取量

  const Wallet({
    this.balance = 0,
    this.totalEarned = 0,
    this.todayEarned = 0,
    this.lastResetDate = '',
  });

  static const int dailyEarnLimit = 100;

  bool get isDailyLimitReached => todayEarned >= dailyEarnLimit;
  int get remainingToday => (dailyEarnLimit - todayEarned).clamp(0, dailyEarnLimit);

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'total_earned': totalEarned,
        'today_earned': todayEarned,
        'last_reset_date': lastResetDate,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balance: (json['balance'] as int?) ?? 0,
        totalEarned: (json['total_earned'] as int?) ?? 0,
        todayEarned: (json['today_earned'] as int?) ?? 0,
        lastResetDate: (json['last_reset_date'] as String?) ?? '',
      );

  Wallet copyWith({
    int? balance,
    int? totalEarned,
    int? todayEarned,
    String? lastResetDate,
  }) =>
      Wallet(
        balance: balance ?? this.balance,
        totalEarned: totalEarned ?? this.totalEarned,
        todayEarned: todayEarned ?? this.todayEarned,
        lastResetDate: lastResetDate ?? this.lastResetDate,
      );
}

// ── 交易类型 ──

enum TxType {
  earnRhythm('earn_rhythm', '节奏游戏'),
  earnMelody('earn_melody', '旋律闯关'),
  earnCollect('earn_collect', '声音收集'),
  earnDaily('earn_daily', '每日挑战'),
  spendShop('spend_shop', '集市兑换'),
  giftReceived('gift_received', '收到的礼物');

  const TxType(this.code, this.label);
  final String code;
  final String label;

  static TxType fromCode(String code) =>
      TxType.values.firstWhere((t) => t.code == code, orElse: () => TxType.earnRhythm);
}

// ── 交易流水 ──

class Transaction {
  final String id; // UUID
  final TxType type;
  final int amount; // 正=收入，负=支出
  final String description; // 人类可读的描述，如"节奏游戏获得 5 颗金松果"
  final String? refId; // 关联的游戏局ID或商品ID
  final DateTime timestamp;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.refId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.code,
        'amount': amount,
        'description': description,
        'ref_id': refId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        type: TxType.fromCode(json['type'] as String),
        amount: json['amount'] as int,
        description: (json['description'] as String?) ?? '',
        refId: json['ref_id'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// ── 商店物品分类 ──

enum ShopCategory {
  avatarFrame('avatar_frame', '头像框'),
  petSkin('pet_skin', '守护动物'),
  treeDeco('tree_deco', '音乐树挂饰'),
  postcardBg('postcard_bg', '明信片信纸'),
  instrument('instrument', '乐器音色');

  const ShopCategory(this.code, this.label);
  final String code;
  final String label;

  static ShopCategory fromCode(String code) =>
      ShopCategory.values.firstWhere((c) => c.code == code, orElse: () => ShopCategory.avatarFrame);
}

// ── 商店物品 ──

class ShopItem {
  final String id;
  final ShopCategory category;
  final String name;
  final String emoji; // 展示用 emoji
  final int price;
  final String? assetPath; // 本地资源路径
  final int unlockTreeLevel; // 音乐树等级解锁限制，0=无限制

  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.emoji,
    required this.price,
    this.assetPath,
    this.unlockTreeLevel = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.code,
        'name': name,
        'emoji': emoji,
        'price': price,
        'asset_path': assetPath,
        'unlock_tree_level': unlockTreeLevel,
      };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        category: ShopCategory.fromCode(json['category'] as String),
        name: json['name'] as String,
        emoji: (json['emoji'] as String?) ?? '🎁',
        price: json['price'] as int,
        assetPath: json['asset_path'] as String?,
        unlockTreeLevel: (json['unlock_tree_level'] as int?) ?? 0,
      );

  // ── 内置商品列表（离线可用） ──
  static List<ShopItem> get builtInItems => [
        // 头像框
        const ShopItem(id: 'frame_spring', category: ShopCategory.avatarFrame, name: '春花框', emoji: '🌸', price: 20),
        const ShopItem(id: 'frame_star', category: ShopCategory.avatarFrame, name: '星星框', emoji: '⭐', price: 30),
        const ShopItem(id: 'frame_rainbow', category: ShopCategory.avatarFrame, name: '彩虹框', emoji: '🌈', price: 50, unlockTreeLevel: 3),
        const ShopItem(id: 'frame_moon', category: ShopCategory.avatarFrame, name: '月亮框', emoji: '🌙', price: 40),
        // 守护动物皮肤
        const ShopItem(id: 'pet_golden_panda', category: ShopCategory.petSkin, name: '金熊猫', emoji: '🐼✨', price: 60, unlockTreeLevel: 2),
        const ShopItem(id: 'pet_blue_tit', category: ShopCategory.petSkin, name: '蓝羽山雀', emoji: '🐦💙', price: 40),
        const ShopItem(id: 'pet_rainbow_frog', category: ShopCategory.petSkin, name: '彩虹蛙', emoji: '🐸🌈', price: 50),
        const ShopItem(id: 'pet_golden_firefly', category: ShopCategory.petSkin, name: '金瓢虫', emoji: '🐞💛', price: 70, unlockTreeLevel: 4),
        const ShopItem(id: 'pet_golden_dog', category: ShopCategory.petSkin, name: '金毛小黄狗', emoji: '🐶💛', price: 60, unlockTreeLevel: 3),
        const ShopItem(id: 'pet_silver_cat', category: ShopCategory.petSkin, name: '银灰小花猫', emoji: '🐱🩶', price: 55, unlockTreeLevel: 3),
        const ShopItem(id: 'pet_yellow_duck', category: ShopCategory.petSkin, name: '黄绒小鸭子', emoji: '🦆💛', price: 50, unlockTreeLevel: 2),
        const ShopItem(id: 'pet_white_goat', category: ShopCategory.petSkin, name: '雪白小山羊', emoji: '🐐🤍', price: 50, unlockTreeLevel: 2),
        const ShopItem(id: 'pet_magic_elf', category: ShopCategory.petSkin, name: '魔法小精灵', emoji: '🧚✨', price: 80, unlockTreeLevel: 5),
        const ShopItem(id: 'pet_wise_elephant', category: ShopCategory.petSkin, name: '智慧小象', emoji: '🐘🧠', price: 70, unlockTreeLevel: 4),
        const ShopItem(id: 'pet_cunning_fox', category: ShopCategory.petSkin, name: '赤焰小狐狸', emoji: '🦊🔥', price: 65, unlockTreeLevel: 3),
        const ShopItem(id: 'pet_gentle_hedgehog', category: ShopCategory.petSkin, name: '温柔小刺猬', emoji: '🦔🌸', price: 55, unlockTreeLevel: 2),
        const ShopItem(id: 'pet_graceful_deer', category: ShopCategory.petSkin, name: '斑点小花鹿', emoji: '🦌🌿', price: 65, unlockTreeLevel: 3),
        const ShopItem(id: 'pet_lively_squirrel', category: ShopCategory.petSkin, name: '活泼小松鼠', emoji: '🐿️🌰', price: 50, unlockTreeLevel: 2),
        const ShopItem(id: 'pet_soft_rabbit', category: ShopCategory.petSkin, name: '软萌小兔子', emoji: '🐰🎀', price: 55, unlockTreeLevel: 3),
        // 音乐树挂饰
        const ShopItem(id: 'deco_bell', category: ShopCategory.treeDeco, name: '风铃', emoji: '🎐', price: 15),
        const ShopItem(id: 'deco_star', category: ShopCategory.treeDeco, name: '小星星', emoji: '🌟', price: 20),
        const ShopItem(id: 'deco_fruit', category: ShopCategory.treeDeco, name: '红果实', emoji: '🍎', price: 25),
        const ShopItem(id: 'deco_lantern', category: ShopCategory.treeDeco, name: '小灯笼', emoji: '🏮', price: 30, unlockTreeLevel: 2),
        const ShopItem(id: 'deco_heart', category: ShopCategory.treeDeco, name: '爱心果', emoji: '💝', price: 35, unlockTreeLevel: 3),
        // 明信片信纸
        const ShopItem(id: 'card_forest', category: ShopCategory.postcardBg, name: '森林信纸', emoji: '🌿', price: 15),
        const ShopItem(id: 'card_ocean', category: ShopCategory.postcardBg, name: '海洋信纸', emoji: '🌊', price: 20),
        const ShopItem(id: 'card_sunset', category: ShopCategory.postcardBg, name: '晚霞信纸', emoji: '🌅', price: 25),
        const ShopItem(id: 'card_night', category: ShopCategory.postcardBg, name: '星空信纸', emoji: '🌌', price: 30, unlockTreeLevel: 2),
        // 乐器音色
        const ShopItem(id: 'inst_flute', category: ShopCategory.instrument, name: '笛子音色', emoji: '🪈', price: 80, unlockTreeLevel: 3),
        const ShopItem(id: 'inst_harp', category: ShopCategory.instrument, name: '竖琴音色', emoji: '🎵', price: 100, unlockTreeLevel: 4),
        const ShopItem(id: 'inst_bell', category: ShopCategory.instrument, name: '钟琴音色', emoji: '🔔', price: 90, unlockTreeLevel: 3),
      ];
}

// ── 背包/库存物品 ──

class InventoryItem {
  final String itemId;
  final int quantity;
  final bool isEquipped;
  final DateTime acquiredTime;

  const InventoryItem({
    required this.itemId,
    this.quantity = 1,
    this.isEquipped = false,
    required this.acquiredTime,
  });

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'quantity': quantity,
        'is_equipped': isEquipped ? 1 : 0,
        'acquired_time': acquiredTime.toIso8601String(),
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        itemId: json['item_id'] as String,
        quantity: (json['quantity'] as int?) ?? 1,
        isEquipped: (json['is_equipped'] as int?) == 1,
        acquiredTime: DateTime.parse(json['acquired_time'] as String),
      );

  InventoryItem copyWith({int? quantity, bool? isEquipped}) => InventoryItem(
        itemId: itemId,
        quantity: quantity ?? this.quantity,
        isEquipped: isEquipped ?? this.isEquipped,
        acquiredTime: acquiredTime,
      );
}

// ── 每日进度 ──

class DailyProgress {
  final String date; // 'YYYY-MM-DD'
  final bool dailyChallengeCompleted;
  final int dailyEarnings;

  const DailyProgress({
    required this.date,
    this.dailyChallengeCompleted = false,
    this.dailyEarnings = 0,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'daily_challenge_completed': dailyChallengeCompleted ? 1 : 0,
        'daily_earnings': dailyEarnings,
      };

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
        date: json['date'] as String,
        dailyChallengeCompleted: (json['daily_challenge_completed'] as int?) == 1,
        dailyEarnings: (json['daily_earnings'] as int?) ?? 0,
      );
}
