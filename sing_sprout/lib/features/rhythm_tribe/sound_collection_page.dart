import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/database_service.dart';
import '../../core/constants/app_routes.dart';

// ═══════════════════════════════════════════════════════════════
// 声音收集图鉴 — 收集大自然的声音
// ═══════════════════════════════════════════════════════════════
///
/// 展示预设的"目标声音"清单，玩家通过田野声景实验室录制声音后
/// 在此查看收集进度。每种声音第一次收集时获得金松果奖励。

class SoundCollectionPage extends StatefulWidget {
  const SoundCollectionPage({super.key});

  @override
  State<SoundCollectionPage> createState() => _SoundCollectionPageState();
}

class _SoundCollectionPageState extends State<SoundCollectionPage> {
  bool _loading = true;
  final Map<String, List<String>> _collectedNamesByCat = {}; // cat → [name, ...]
  int _totalCollected = 0;

  // ── 目标声音清单 ──
  static const _targets = <_SoundTarget>[
    // 动物 (6)
    _SoundTarget('🐱', '猫叫', _SoundCat.animal),
    _SoundTarget('🐕', '狗叫', _SoundCat.animal),
    _SoundTarget('🐦', '鸟鸣', _SoundCat.animal),
    _SoundTarget('🐸', '蛙鸣', _SoundCat.animal),
    _SoundTarget('🦗', '虫鸣', _SoundCat.animal),
    _SoundTarget('🐄', '牛叫', _SoundCat.animal),

    // 自然 (6)
    _SoundTarget('🌧️', '雨声', _SoundCat.nature),
    _SoundTarget('💨', '风声', _SoundCat.nature),
    _SoundTarget('🌊', '海浪', _SoundCat.nature),
    _SoundTarget('⛈️', '雷声', _SoundCat.nature),
    _SoundTarget('💧', '溪流', _SoundCat.nature),
    _SoundTarget('🍂', '落叶', _SoundCat.nature),

    // 人声 (4)
    _SoundTarget('😊', '笑声', _SoundCat.voice),
    _SoundTarget('👏', '拍手', _SoundCat.voice),
    _SoundTarget('🎵', '哼唱', _SoundCat.voice),
    _SoundTarget('🗣️', '说话', _SoundCat.voice),

    // 机械/乐器 (4)
    _SoundTarget('🔔', '铃声', _SoundCat.mechanical),
    _SoundTarget('🚗', '汽车', _SoundCat.mechanical),
    _SoundTarget('🎹', '钢琴', _SoundCat.mechanical),
    _SoundTarget('🥁', '鼓声', _SoundCat.mechanical),
  ];

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    final db = DatabaseService();
    try {
      final dbRef = await db.database;
      // 按分类统计录音数量
      final rows = await dbRef.rawQuery(
        'SELECT type, COUNT(*) as cnt FROM sound_samples GROUP BY type',
      );

      _collectedNamesByCat.clear();

      // 统计每个分类的录音总数
      final catCounts = <String, int>{};
      for (final r in rows) {
        final cat = _catFromDbType(r['type'] as String?);
        final cnt = (r['cnt'] as num).toInt();
        catCounts[cat] = (catCounts[cat] ?? 0) + cnt;
      }

      // 按录音数量依次解锁该分类下的目标
      for (final cat in _SoundCat.values) {
        final targetsInCat = _targets.where((t) => t.cat == cat).toList();
        final unlockCount = (catCounts[cat] ?? 0).clamp(0, targetsInCat.length);

        _collectedNamesByCat[cat] = targetsInCat
            .take(unlockCount)
            .map((t) => t.name)
            .toList();
      }

      // 计算总收集数
      int count = 0;
      for (final names in _collectedNamesByCat.values) {
        count += names.length;
      }
      _totalCollected = count;
    } catch (_) {
      // 数据库为空或不存在的处理
    }
    if (mounted) setState(() => _loading = false);
  }

  int _categoryProgress(String cat) =>
      _targets.where((t) => t.cat == cat).length;

  int _categoryCollected(String cat) =>
      (_collectedNamesByCat[cat]?.length ?? 0)
          .clamp(0, _categoryProgress(cat));

  bool _isCollected(_SoundTarget target) =>
      _collectedNamesByCat[target.cat]?.contains(target.name) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('声音收集图鉴'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.fieldSoundLabRecord),
            icon: const Text('🎤', style: TextStyle(fontSize: 18)),
            label: const Text('去录音'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadCollection,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProgressBanner(),
                  const SizedBox(height: 20),
                  ..._SoundCat.values.map(_buildCategorySection),
                  const SizedBox(height: 12),
                  _buildHint(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressBanner() {
    final pct = (_totalCollected / _targets.length * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6BCB77).withValues(alpha: 0.15),
            const Color(0xFF4D96FF).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Text(pct >= 100 ? '🏆' : '🎧', style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pct >= 100 ? '图鉴完成！' : '声音收集进度',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '已发现 $_totalCollected / ${_targets.length} 种声音',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalCollected / _targets.length,
                    minHeight: 8,
                    backgroundColor: AppTheme.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String cat) {
    final items = _targets.where((t) => t.cat == cat).toList();
    final collected = _categoryCollected(cat);
    final total = _categoryProgress(cat);

    final catLabel = switch (cat) {
      _SoundCat.animal => '🐾 动物',
      _SoundCat.nature => '🌿 自然',
      _SoundCat.voice => '😊 人声',
      _SoundCat.mechanical => '🔧 器物',
      _ => '其他',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text(catLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Text('$collected/$total',
                  style: TextStyle(
                    fontSize: 13,
                    color: collected == total ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  )),
              if (collected == total) const SizedBox(width: 4),
              if (collected == total) const Text('✅', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _SoundCard(
            target: items[i],
            collected: _isCollected(items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡 怎么收集声音？',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          SizedBox(height: 8),
          Text(
            '1. 点击右上角「去录音」进入田野声景实验室\n'
            '2. 录制你身边的声音（动物叫、风雨声、乐器等）\n'
            '3. 命名保存后，声音会自动出现在图鉴中\n'
            '4. 每种声音首次收集奖励 +3 🌰',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.7),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

class _SoundCat {
  static const animal = 'animal';
  static const nature = 'nature';
  static const voice = 'voice';
  static const mechanical = 'mechanical';
  static const values = [animal, nature, voice, mechanical];
}

class _SoundTarget {
  final String emoji;
  final String name;
  final String cat;
  const _SoundTarget(this.emoji, this.name, this.cat);
}

// ═══════════════════════════════════════════════════════════════
// 声音卡片
// ═══════════════════════════════════════════════════════════════

class _SoundCard extends StatelessWidget {
  final _SoundTarget target;
  final bool collected;

  const _SoundCard({required this.target, required this.collected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: collected ? Colors.white : AppTheme.bgWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: collected ? AppTheme.primaryGreen.withValues(alpha: 0.4) : AppTheme.divider,
          width: collected ? 1.5 : 1,
        ),
        boxShadow: collected
            ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            collected ? target.emoji : '❓',
            style: TextStyle(fontSize: collected ? 32 : 24),
          ),
          const SizedBox(height: 4),
          Text(
            collected ? target.name : '???',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: collected ? FontWeight.w600 : FontWeight.w400,
              color: collected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          if (collected)
            const Text('已收集', style: TextStyle(fontSize: 10, color: AppTheme.primaryGreen)),
        ],
      ),
    );
  }
}
