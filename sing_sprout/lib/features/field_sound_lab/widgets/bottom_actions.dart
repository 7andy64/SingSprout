import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/enums.dart';
import '../../../shared/models/sound_sample.dart';
import '../../../shared/providers/app_state.dart';
import '../view_models/field_sound_lab_view_model.dart';

/// 底部操作栏 — 保存按钮 + 快捷入口
class BottomActions extends StatelessWidget {
  final FieldSoundLabViewModel vm;

  const BottomActions({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Save button ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: vm.hasRecording
                      ? () => _saveToLibrary(context)
                      : null,
                  icon: const Icon(Icons.save_alt_rounded, size: 22),
                  label: const Text(
                    '保存到我的声音库',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7CB342),
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Quick actions ──
              Row(
                children: [
                  // Weekly tasks — 基于真实声音数据
                  Expanded(
                    child: _WeeklyTaskTile(vm: vm),
                  ),
                  const SizedBox(width: 12),
                  // Sound library
                  Expanded(
                    child: _QuickActionTile(
                      icon: '🎵',
                      label: '我的声音库',
                      subtitle:
                          '${context.watch<AppState>().totalSounds} 个声音',
                      color: const Color(0xFF42A5F5),
                      onTap: () => context.push(AppRoutes.sounds),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToLibrary(BuildContext context) async {
    if (vm.recordedFilePath == null) return;

    final nameCtrl = TextEditingController(
      text: '田野声音 ${DateTime.now().month}/${DateTime.now().day}',
    );

    final result = await showDialog<({String name, SoundType type})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Use local state for dialog type selection
          var selectedType = vm.detectedType;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('保存声音', style: TextStyle(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '给声音起个名字吧',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit, size: 20),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SoundType.values.map((t) {
                    final isSelected = t == selectedType;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(FieldSoundLabViewModel.typeIcon(t),
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(t.label),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF7CB342)
                          .withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setDlg(() => selectedType = t),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, (name: name, type: selectedType));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7CB342),
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;

    final sample = SoundSample.create(
      name: result.name,
      audioPath: vm.recordedFilePath!,
      type: result.type,
      bpm: vm.detectedBpm,
    );
    await context.read<AppState>().addSound(sample);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 「${result.name}」已保存到声音库'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════
//  Weekly Task Tile — 基于真实数据
// ═══════════════════════════════════════════════

class _WeeklyTaskTile extends StatefulWidget {
  final FieldSoundLabViewModel vm;
  const _WeeklyTaskTile({required this.vm});

  @override
  State<_WeeklyTaskTile> createState() => _WeeklyTaskTileState();
}

class _WeeklyTaskTileState extends State<_WeeklyTaskTile> {
  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  void _update() {
    final sounds = context.read<AppState>().sounds;
    final typesThisWeek = _getWeeklyTypes(sounds);
    widget.vm.updateWeeklyProgress(typesThisWeek);
  }

  @override
  Widget build(BuildContext context) {
    final collected = widget.vm.weeklyCollected;
    final target = widget.vm.weeklyTarget;
    final color = const Color(0xFFFF7043);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              collected >= target
                  ? '🎉 本周任务已完成！已采集 $collected 种声音'
                  : '🔍 还差 ${target - collected} 种声音，继续探索吧！',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '本周探索任务',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '已采集 $collected/$target 种',
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: target > 0 ? collected / target : 0,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 提取本周一到今天之间所有声音样本的类型列表
  List<SoundType> _getWeeklyTypes(List<SoundSample> sounds) {
    final now = DateTime.now();
    // 本周一 00:00
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    return sounds
        .where((s) => s.createdAt.isAfter(weekStart))
        .map((s) => s.type)
        .toList();
  }
}

// ═══════════════════════════════════════════════
//  Generic Quick Action Tile
// ═══════════════════════════════════════════════

class _QuickActionTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}
