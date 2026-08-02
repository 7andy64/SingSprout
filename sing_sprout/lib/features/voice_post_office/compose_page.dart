import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/connectivity_provider.dart';
import '../../shared/services/dash_scope_service.dart';
import '../../shared/services/outbox_queue_service.dart';
import '../../shared/services/social_share_service.dart';
import '../../shared/utils/postcard_generator.dart';

/// 撰写音乐明信片 — 选择作品 + 写一句话 + 语音祝福 → 生成卡片 → 分享
class ComposePage extends StatefulWidget {
  final String? initialWorkId;
  final String? replyToId;
  const ComposePage({super.key, this.initialWorkId, this.replyToId});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _messageController = TextEditingController();
  final _greetingController = TextEditingController();
  MusicWork? _selectedWork;
  bool _generating = false;
  bool _generatingGreeting = false;
  String? _greetingAudioPath;
  String? _greetingText;

  // 常用语音选择
  static const _voices = [
    ('longhuhu_v3', '龙呼呼 (天真女童)'),
    ('longniuniu_v3', '龙牛牛 (阳光男童)'),
    ('longwan_v3', '龙婉 (温柔女声)'),
    ('longanrou_v3', '龙安柔 (娴静女声)'),
    ('longcheng_v3', '龙橙 (青年男声)'),
  ];
  String _selectedVoice = 'longhuhu_v3';

  List<MusicWork> get _works {
    final appState = context.read<AppState>();
    return appState.works;
  }

  bool get _isReply => widget.replyToId != null && widget.replyToId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
    _greetingController.addListener(_onInputChanged);
    if (widget.initialWorkId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appState = context.read<AppState>();
        final work = appState.works
            .where((w) => w.id == widget.initialWorkId)
            .firstOrNull;
        if (work != null && mounted) {
          setState(() => _selectedWork = work);
        }
      });
    }
  }

  void _onInputChanged() => setState(() {});

  @override
  void dispose() {
    _messageController.removeListener(_onInputChanged);
    _greetingController.removeListener(_onInputChanged);
    _messageController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  Future<void> _generateGreeting() async {
    final text = _greetingController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入语音祝福的文字')),
      );
      return;
    }
    setState(() => _generatingGreeting = true);
    try {
      final audioPath = await DashScopeService().synthesizeSpeech(
        text: text,
        voice: _selectedVoice,
      );
      if (!mounted) return;
      if (audioPath != null) {
        setState(() {
          _greetingAudioPath = audioPath;
          _greetingText = text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音祝福已生成 ✅')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音生成失败，请检查网络或 API Key')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingGreeting = false);
    }
  }

  Future<void> _generateAndShare() async {
    if (_selectedWork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一首作品')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final appState = context.read<AppState>();
      final profile = appState.userProfile;
      final senderName = profile?.nickname ?? '声芽用户';
      final isOnline = context.read<ConnectivityProvider>().isConnected;

      // 1. 生成明信片图片
      final imagePath = await PostcardGenerator.generate(
        work: _selectedWork!,
        message: _messageController.text.trim(),
        senderName: senderName,
        greetingText: _greetingText,
      );

      // 2. 保存明信片记录
      final card = VoiceCard.send(
        senderId: profile?.localId ?? 'anonymous',
        workId: _selectedWork!.id,
        audioPath: _selectedWork!.audioPath,
        textContent: _messageController.text.trim(),
        coverUrl: imagePath,
        replyToId: widget.replyToId,
        greetingAudioPath: _greetingAudioPath,
        greetingText: _greetingText,
      );
      await appState.addVoiceCard(card);

      if (!mounted) return;

      if (isOnline) {
        // 3. 在线：弹出分享选项面板
        if (!mounted) return;
        SocialShareService.showShareOptions(
          context,
          imagePath: imagePath,
          title: _selectedWork!.title,
          message: _messageController.text.trim(),
        );
      } else {
        // 3. 离线：缓存到发件箱
        await OutboxQueueService().enqueue(card);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到发件箱，联网后自动发送')),
        );
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(_isReply ? '回复明信片' : '写音乐明信片'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 回复提示
              if (_isReply)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWarm.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('💌', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '正在回复对方发来的明信片',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

              // 选择音乐作品
              const Text('选择一首作品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              _works.isNotEmpty
                  ? _WorkSelector(
                      works: _works,
                      selected: _selectedWork,
                      onSelected: (w) => setState(() => _selectedWork = w),
                    )
                  : Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withValues(alpha: 0.06),
                            AppTheme.primaryWarm.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('还没有作品，先去哼唱花园创作吧', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ),

              const SizedBox(height: 24),

              // 想说的话
              const Text('想说的话', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLength: 100,
                maxLines: 3,
                decoration: const InputDecoration(hintText: '比如：妈妈我好想你...'),
              ),

              const SizedBox(height: 24),

              // 语音祝福
              const Text('📢 语音祝福', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(
                '输入文字，AI 会合成孩子的声音作为语音祝福',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 10),

              // 语音选择
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _voices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final v = _voices[index];
                    final selected = v.$1 == _selectedVoice;
                    return ChoiceChip(
                      label: Text(v.$2, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textSecondary)),
                      selected: selected,
                      selectedColor: AppTheme.primaryGreen,
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.06),
                      onSelected: (_) => setState(() => _selectedVoice = v.$1),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // 祝福语输入 + 生成按钮
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _greetingController,
                      maxLength: 50,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '比如：妈妈我爱你，这是我为你唱的歌',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _generatingGreeting ? null : _generateGreeting,
                      icon: _generatingGreeting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('🎙️', style: TextStyle(fontSize: 18)),
                      label: Text(_generatingGreeting ? '生成中' : '生成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              // 已生成的状态
              if (_greetingAudioPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🎵', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '语音祝福已就绪：${_greetingText ?? ''}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _greetingAudioPath = null;
                              _greetingText = null;
                            });
                          },
                          child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 生成并分享
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generateAndShare,
                  icon: _generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('📤', style: TextStyle(fontSize: 20)),
                  label: Text(_generating ? '生成中...' : '生成明信片并分享'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '将通过微信/QQ/钉钉发送给家人',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 作品选择器 — 横向滚动的作品卡片列表
class _WorkSelector extends StatelessWidget {
  final List<MusicWork> works;
  final MusicWork? selected;
  final ValueChanged<MusicWork> onSelected;

  const _WorkSelector({required this.works, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final work = works[index];
          final isSelected = work.id == selected?.id;
          return GestureDetector(
            onTap: () => onSelected(work),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.divider, width: isSelected ? 2 : 1),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    work.title,
                    style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${work.styleSeed.label} · ${_formatShort(work.duration)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatShort(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
