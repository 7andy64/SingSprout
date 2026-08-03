import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 乐器伙伴圈 — 正六边形 6 顶点排列
///
/// [ownedInstrumentIds] 为商店购买的乐器 ID 集合，未购买的乐器显示 🔒 且不可点击。
class InstrumentMixer extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Set<String> ownedInstrumentIds;

  const InstrumentMixer({
    super.key,
    required this.value,
    required this.onChanged,
    this.ownedInstrumentIds = const {},
  });

  @override
  State<InstrumentMixer> createState() => _InstrumentMixerState();
}

class _InstrumentMixerState extends State<InstrumentMixer> {
  /// 乐器定义：icon、名称、对应的商店物品 ID（null = 免费）
  static const _instruments = [
    _Instrument('🥁', '鼓', null),           // 免费
    _Instrument('🎹', '钢琴', null),          // 免费
    _Instrument('🎸', '吉他', null),          // 免费
    _Instrument('🪈', '笛子', 'inst_flute'),  // 需购买
    _Instrument('🔔', '钟琴', 'inst_bell'),   // 需购买
  ];

  late List<bool> _active;

  @override
  void initState() {
    super.initState();
    _active = List.filled(_instruments.length, false);
    final activeCount = (widget.value * _instruments.length).round();
    for (int i = 0; i < activeCount; i++) {
      _active[i] = true;
    }
  }

  /// 该乐器是否需要购买且用户未拥有
  bool _isLocked(int index) {
    final shopId = _instruments[index].shopId;
    if (shopId == null) return false;
    return !widget.ownedInstrumentIds.contains(shopId);
  }

  void _toggle(int index) {
    if (_isLocked(index)) return;
    setState(() {
      _active[index] = !_active[index];
      final newValue = _active.where((a) => a).length / _instruments.length;
      widget.onChanged(newValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _active.where((a) => a).length;
    final richLabel = activeCount == 0
        ? '纯人声'
        : activeCount <= 1
            ? '加点乐器'
            : activeCount <= 3
                ? '小乐队'
                : '大合奏！';

    const r = 65.0;
    const w = 280.0;
    const h = 190.0;
    const cx = w / 2;
    const cy = 95.0;
    const btnSize = 40.0;

    const angles = [0.0, pi / 3, 2 * pi / 3, pi, 4 * pi / 3, 5 * pi / 3];
    const angleOffset = -pi / 2;

    return Center(
      child: SizedBox(
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👤 纯人声',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWarm.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(richLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primarySoil)),
                ),
                const Text('丰富配器 🎶',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 6; i++)
                    _buildVertex(
                      i,
                      angles[i] + angleOffset,
                      cx,
                      cy,
                      r,
                      btnSize,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVertex(
    int index,
    double angle,
    double cx,
    double cy,
    double r,
    double size,
  ) {
    final dx = r * cos(angle);
    final dy = r * sin(angle);
    final isBoy = index == 3;
    final locked = !isBoy && index < 3
        ? _isLocked(index)
        : (!isBoy && index > 3 ? _isLocked(index - 1) : false);

    Color bg;
    Color border;
    double borderW;
    List<BoxShadow>? shadow;

    if (isBoy) {
      bg = AppTheme.primaryGreen.withValues(alpha: 0.1);
      border = AppTheme.primaryGreen.withValues(alpha: 0.3);
      borderW = 2;
    } else if (locked) {
      bg = AppTheme.divider.withValues(alpha: 0.2);
      border = AppTheme.divider;
      borderW = 1;
    } else {
      final active = _active[index < 3 ? index : index - 1];
      bg = active
          ? AppTheme.primaryGreen.withValues(alpha: 0.15)
          : AppTheme.divider.withValues(alpha: 0.3);
      border = active ? AppTheme.primaryGreen : AppTheme.divider;
      borderW = active ? 2.0 : 1.0;
    }

    if (!locked && (isBoy || _active[index < 3 ? index : index - 1])) {
      shadow = [
        BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 6),
      ];
    }

    final icon = locked
        ? '🔒'
        : isBoy
            ? '🧒'
            : _instruments[index < 3 ? index : index - 1].icon;
    final iconSize = locked
        ? 18.0
        : isBoy
            ? 24.0
            : (_active[index < 3 ? index : index - 1] ? 22.0 : 18.0);
    final label = locked
        ? '需购买'
        : isBoy
            ? ''
            : _instruments[index < 3 ? index : index - 1].label;

    return Positioned(
      left: cx + dx - size / 2,
      top: cy + dy - size / 2,
      child: GestureDetector(
        onTap: (isBoy || locked)
            ? () {
                if (locked && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('「$label」需要去森林集市购买哦 🛍️'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            : () => _toggle(index < 3 ? index : index - 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: borderW),
            boxShadow: shadow,
          ),
          child: Center(
              child: Text(icon, style: TextStyle(fontSize: iconSize))),
        ),
      ),
    );
  }
}

class _Instrument {
  final String icon;
  final String label;
  final String? shopId; // null = free, non-null = must purchase
  const _Instrument(this.icon, this.label, this.shopId);
}
