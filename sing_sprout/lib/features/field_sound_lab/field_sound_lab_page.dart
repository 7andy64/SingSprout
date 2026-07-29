import 'package:flutter/material.dart';
import 'view_models/field_sound_lab_view_model.dart';
import 'widgets/wave_visualization.dart';
import 'widgets/recording_controls.dart';
import 'widgets/analysis_card.dart';
import 'widgets/bottom_actions.dart';

/// 田野声音实验室 — 主页面
///
/// 功能：
/// - 🎤 长按录音（最长 30s）
/// - 📊 实时声波可视化（CustomPaint）
/// - 🔄 保存前回放试听
/// - 🤖 AI 分析结果卡片（当前为模拟数据）
/// - 🎯 本周探索任务（基于真实声音库数据）
/// - 💾 保存到声音库
class FieldSoundLabPage extends StatefulWidget {
  const FieldSoundLabPage({super.key});

  @override
  State<FieldSoundLabPage> createState() => _FieldSoundLabPageState();
}

class _FieldSoundLabPageState extends State<FieldSoundLabPage>
    with TickerProviderStateMixin {
  late final FieldSoundLabViewModel _vm;
  late final AnimationController _waveAnimController;
  late final AnimationController _cardSlideController;
  late final Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _vm = FieldSoundLabViewModel()..init();

    // Wave animation (continuous)
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Card slide-in animation
    _cardSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardSlideController,
      curve: Curves.easeOutCubic,
    ));

    // Listen for analysis card visibility to trigger slide animation
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (_vm.showAnalysisCard && !_cardSlideController.isAnimating) {
      _cardSlideController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _waveAnimController.dispose();
    _cardSlideController.dispose();
    super.dispose();
  }

  /// 权限被拒绝时弹出引导对话框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎤', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Text('需要麦克风权限', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          '开启麦克风权限后，\n才能采集身边的声音哦～',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _vm.requestPermission();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7CB342),
            ),
            child: const Text('去开启'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F1),
      appBar: AppBar(
        title: const Text('🎧 田野声音实验室'),
        centerTitle: true,
        backgroundColor: const Color(0xFF7CB342),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            return Column(
              children: [
                // ── Wave visualization ──
                WaveVisualization(
                  vm: _vm,
                  waveAnimController: _waveAnimController,
                ),

                // ── Recording controls + playback ──
                RecordingControls(
                  vm: _vm,
                  onPermissionDenied: _showPermissionDialog,
                ),

                // ── AI analysis card ──
                AnalysisCard(
                  vm: _vm,
                  cardSlideController: _cardSlideController,
                  cardSlideAnimation: _cardSlideAnimation,
                ),

                const Spacer(),

                // ── Bottom actions ──
                BottomActions(vm: _vm),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}
