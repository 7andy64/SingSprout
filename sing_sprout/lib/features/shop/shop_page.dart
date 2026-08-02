import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';
import '../../shared/providers/app_state.dart';

/// 森林集市 — 金松果虚拟物品商店
///
/// 面向 9-12 岁儿童设计：大图标、emoji 展示、明码标价、简单交互。
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _categories = [
    ('avatar_frame', '头像框', '🖼️'),
    ('pet_skin', '守护动物', '🐾'),
    ('tree_deco', '树挂饰', '🎄'),
    ('postcard_bg', '信纸', '✉️'),
    ('instrument', '乐器', '🎵'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('森林集市'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: _categories.map((c) {
            return Tab(text: '${c.$3} ${c.$2}');
          }).toList(),
        ),
      ),
      body: Consumer2<EconomyProvider, AppState>(
        builder: (context, economy, appState, _) {
          return Column(
            children: [
              _BalanceBar(economy: economy),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((cat) {
                    final items = economy.shopItems
                        .where((i) => i.category.code == cat.$1)
                        .toList();
                    return _ItemGrid(
                      items: items,
                      economy: economy,
                      treeState: appState.treeData?.treeState ?? TreeState.sprouting,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 顶部余额栏
class _BalanceBar extends StatelessWidget {
  final EconomyProvider economy;

  const _BalanceBar({required this.economy});

  @override
  Widget build(BuildContext context) {
    final dailyText = economy.isDailyLimitReached
        ? '今天的小松果们已经睡觉啦，明天再来吧'
        : '今天还能获得 ${economy.remainingToday} 颗';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B9A4B), Color(0xFF7CB342)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🌰', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '金松果 ${economy.balance}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dailyText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 商品网格
class _ItemGrid extends StatelessWidget {
  final List<ShopItem> items;
  final EconomyProvider economy;
  final TreeState treeState;

  const _ItemGrid({
    required this.items,
    required this.economy,
    required this.treeState,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌿', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('暂无商品', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _ShopItemCard(
        item: items[index],
        economy: economy,
        treeState: treeState,
      ),
    );
  }
}

/// 单个商品卡片
class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final EconomyProvider economy;
  final TreeState treeState;

  static int _treeLevel(TreeState s) => switch (s) {
    TreeState.sprouting => 0,
    TreeState.quiet => 0,
    TreeState.growing => 1,
    TreeState.thinking => 2,
    TreeState.blooming => 3,
  };

  const _ShopItemCard({
    required this.item,
    required this.economy,
    required this.treeState,
  });

  void _onTap(BuildContext context) async {
    final owned = economy.ownedItemIds.contains(item.id);
    final equipped = economy.equippedItemIds.contains(item.id);

    if (equipped) {
      // 点击已装备 → 卸下
      await economy.unequipItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已卸下「${item.name}」'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (owned) {
      // 点击已拥有 → 装备
      await economy.equipItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已装备「${item.name}」${item.emoji}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // 未拥有 → 购买确认
    _showBuyDialog(context);
  }

  void _showBuyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.emoji, style: const TextStyle(fontSize: 40), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('价格：${item.price} 颗金松果 🌰',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('再看看'),
          ),
          FilledButton(
            onPressed: economy.canAfford(item.price)
                ? () {
                    Navigator.pop(ctx);
                    final error = economy.buyItem(item);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    }
                  }
                : null,
            child: Text(economy.canAfford(item.price) ? '兑换' : '金松果不够'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceAround,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owned = economy.ownedItemIds.contains(item.id);
    final equipped = economy.equippedItemIds.contains(item.id);
    final level = _treeLevel(treeState);
    final locked = item.unlockTreeLevel > 0 && level < item.unlockTreeLevel;

    return GestureDetector(
      onTap: locked ? null : () => _onTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: equipped ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: equipped ? AppTheme.primaryGreen : AppTheme.divider,
            width: equipped ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked) ...[
              const Text('🔒', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 2),
              Text('Lv.${item.unlockTreeLevel} 解锁',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ] else ...[
              Text(item.emoji, style: const TextStyle(fontSize: 34)),
              if (equipped)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('使用中', style: TextStyle(fontSize: 9, color: Colors.white)),
                ),
              if (owned && !equipped)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('已拥有', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!owned)
              Text(
                '🌰 ${item.price}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primarySoil),
              ),
          ],
        ),
      ),
    );
  }
}
