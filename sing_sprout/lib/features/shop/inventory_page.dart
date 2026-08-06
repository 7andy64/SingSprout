import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';

/// 我的背包 — 展示已拥有的虚拟物品，支持装备/卸下
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的背包'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.push('/shop'),
            child: const Text('去集市 🛍️'),
          ),
        ],
      ),
      body: Consumer<EconomyProvider>(
        builder: (context, economy, _) {
          if (economy.inventory.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎒', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('背包空空如也',
                      style: TextStyle(fontSize: 18, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('去森林集市逛逛吧',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/shop'),
                    child: const Text('去森林集市'),
                  ),
                ],
              ),
            );
          }

          final categories = _groupByCategory(economy);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: categories.entries.map((entry) {
              return _CategorySection(
                category: entry.key,
                items: entry.value,
                economy: economy,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Map<ShopCategory, List<InventoryItem>> _groupByCategory(EconomyProvider economy) {
    final map = <ShopCategory, List<InventoryItem>>{};
    for (final inv in economy.inventory) {
      final shopItem = economy.shopItems.where((s) => s.id == inv.itemId).firstOrNull;
      final cat = shopItem?.category ?? ShopCategory.avatarFrame;
      map.putIfAbsent(cat, () => []);
      map[cat]!.add(inv);
    }
    return map;
  }
}

class _CategorySection extends StatelessWidget {
  final ShopCategory category;
  final List<InventoryItem> items;
  final EconomyProvider economy;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.economy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            category.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        ...items.map((inv) {
          final shopItem = economy.shopItems.where((s) => s.id == inv.itemId).firstOrNull;
          if (shopItem == null) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(shopItem.emoji, style: const TextStyle(fontSize: 32)),
              title: Text(shopItem.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: inv.isEquipped
                  ? const Text('使用中', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12))
                  : null,
              trailing: inv.isEquipped
                  ? TextButton(
                      onPressed: () => economy.unequipItem(inv.itemId),
                      child: const Text('卸下'),
                    )
                  : FilledButton(
                      onPressed: () => economy.equipItem(inv.itemId),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 36),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('装备'),
                    ),
            ),
          );
        }),
      ],
    );
  }
}
