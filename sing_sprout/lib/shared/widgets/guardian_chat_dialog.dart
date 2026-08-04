import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/guardian_animal_service.dart';

/// 守护动物聊天对话框。
///
/// 通过静态方法 [GuardianChatDialog.show] 弹出，占屏幕 70% 高度。
///
/// 用法：
/// ```dart
/// // 不传 apiKey，自动从安全存储读取
/// GuardianChatDialog.show(context, animal: GuardianAnimal.panda);
///
/// // 显式传入 apiKey
/// GuardianChatDialog.show(context, animal: GuardianAnimal.panda, apiKey: 'sk-xxx');
/// ```
class GuardianChatDialog extends StatefulWidget {
  final GuardianAnimal animal;
  final String apiKey;
  final String? model;

  const GuardianChatDialog({
    super.key,
    required this.animal,
    required this.apiKey,
    this.model,
  });

  /// 弹出守护动物聊天对话框。
  ///
  /// [apiKey] 可选 — 不传则自动从安全存储中读取。
  static void show(
    BuildContext context, {
    required GuardianAnimal animal,
    String? apiKey,
    String? model,
  }) {
    // 异步解析 key，拿到后弹出
    _resolveApiKey(apiKey).then((key) {
      if (!context.mounted) return;
      if (key == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('还没有设置 AI 魔法钥匙，请联系大人帮忙配置哦～'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => GuardianChatDialog(
          animal: animal,
          apiKey: key,
          model: model,
        ),
      );
    });
  }

  static const _keyStorageKey = 'guardian_animal_api_key';

  static Future<String?> _resolveApiKey(String? provided) async {
    if (provided != null && provided.trim().isNotEmpty) return provided.trim();
    const storage = FlutterSecureStorage();
    // 先读守护动物专用 Key，再回退读 DashScope 通用 Key
    final key = await storage.read(key: _keyStorageKey);
    if (key != null && key.isNotEmpty) return key;
    return await storage.read(key: 'dashscope_api_key');
  }

  @override
  State<GuardianChatDialog> createState() => _GuardianChatDialogState();
}

class _GuardianChatDialogState extends State<GuardianChatDialog> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];
  bool _isLoading = false;
  late final GuardianAnimalService _service;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _service = GuardianAnimalService(
      apiKey: widget.apiKey,
      model: widget.model ?? 'qwen-flash',
      animalType: _mapAnimalType(widget.animal),
      animalName: _mapAnimalName(widget.animal),
    );
  }

  static String _mapAnimalType(GuardianAnimal animal) {
    return switch (animal) {
      GuardianAnimal.panda => 'panda',
      GuardianAnimal.tit => 'sparrow',
      GuardianAnimal.frog => 'frog',
      GuardianAnimal.firefly => 'firefly',
    };
  }

  static String _mapAnimalName(GuardianAnimal animal) {
    return switch (animal) {
      GuardianAnimal.panda => '咕咕',
      GuardianAnimal.tit => '啾啾',
      GuardianAnimal.frog => '呱呱',
      GuardianAnimal.firefly => '闪闪',
    };
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── 发送消息 ──

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _errorText = null;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final reply = await _service.chatRaw(text);
      if (!mounted) return;

      if (reply != null) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isUser: false));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorText = '咕咕好像走神了，再试一次吧～';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = '网络好像不太好，等会儿再试试吧～';
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.7,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // ═══ 顶部标题栏 ═══
          _buildHeader(),

          const Divider(height: 1, color: AppTheme.divider),

          // ═══ 聊天记录 ═══
          Expanded(child: _buildChatList()),

          // ═══ 错误提示 ═══
          if (_errorText != null) _buildErrorBanner(),

          // ═══ 底部输入栏 ═══
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── 顶部 ──

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // 动物头像
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.animal.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 名字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.animal.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  '在线陪聊中',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),

          // 关闭按钮
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 22),
            color: AppTheme.textSecondary,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── 聊天列表 ──

  Widget _buildChatList() {
    if (_messages.isEmpty && !_isLoading) {
      return _buildEmptyHint();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 最后一个位置显示加载动画
        if (_isLoading && index == _messages.length) {
          return _buildLoadingBubble();
        }

        final msg = _messages[index];
        return _buildBubble(msg);
      },
    );
  }

  /// 空消息时的引导提示。
  Widget _buildEmptyHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.animal.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 14),
            Text(
              '和${widget.animal.displayName}打个招呼吧！',
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '可以问我任何问题哦～',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条消息气泡。
  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI 头像
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.animal.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],

          // 气泡内容
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryGreen
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkCard
                        : const Color(0xFFF0F0F0)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: isUser
                      ? Colors.white
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ),

          // 用户头像（占位）
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primarySoil.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person, size: 16, color: AppTheme.primarySoil),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// AI 思考中的加载气泡。
  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(widget.animal.emoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkCard
                  : const Color(0xFFF0F0F0),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: _ThinkingDots(),
          ),
        ],
      ),
    );
  }

  // ── 错误提示 ──

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorText = null),
            child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 输入栏 ──

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              enabled: !_isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFBDBDBD),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkCard
                    : const Color(0xFFF5F5F5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 发送按钮
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: _isLoading
                  ? AppTheme.textSecondary
                  : AppTheme.primaryGreen,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                splashRadius: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  内部类型
// ═══════════════════════════════════════════

/// 聊天消息
class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

/// 思考中动画指示器。
///
/// 三个圆点依次弹跳，模拟"正在输入..."效果。
class _ThinkingDots extends StatefulWidget {
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final offset = _easeOutBounce(t) * -6;
            final opacity = 0.3 + _easeOutBounce(t) * 0.7;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _easeOutBounce(double t) {
    const n1 = 7.5625;
    const d1 = 2.75;
    if (t < 1 / d1) {
      return n1 * t * t;
    } else if (t < 2 / d1) {
      return n1 * (t -= 1.5 / d1) * t + 0.75;
    } else if (t < 2.5 / d1) {
      return n1 * (t -= 2.25 / d1) * t + 0.9375;
    } else {
      return n1 * (t -= 2.625 / d1) * t + 0.984375;
    }
  }
}
