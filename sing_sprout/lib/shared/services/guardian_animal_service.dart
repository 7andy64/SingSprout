import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// 与小朋友互动的守护动物 AI 对话服务。
///
/// 基于阿里云百炼 DashScope Qwen 模型，提供安全、友好的陪伴式聊天。
/// 通过 systemPrompt 定义守护动物的人设（如名字、性格、说话风格），
/// 确保所有回复符合儿童内容安全标准。
///
/// 用法：
/// ```dart
/// final guardian = GuardianAnimalService();
///
/// // 配置（只需一次）
/// await guardian.setApiKey('your-dashscope-key');
/// guardian.setModel('qwen-flash');           // 可选，默认 qwen-flash
/// guardian.setSystemPrompt('你叫咕咕，是一只...'); // 可选，有默认提示词
///
/// // 对话
/// final result = await guardian.chat('你好！');
/// if (result.isSuccess) {
///   print(result.reply); // 咕咕的回复
/// } else {
///   print(result.error); // 错误信息
/// }
/// ```
class GuardianAnimalService {
  static final GuardianAnimalService _instance = GuardianAnimalService._();

  /// 获取或创建服务实例。
  ///
  /// 无参调用返回全局单例（适合持久化 Key 后反复使用）：
  /// ```dart
  /// final service = GuardianAnimalService();
  /// await service.setApiKey('sk-xxx');
  /// ```
  ///
  /// 传入 [apiKey]/[model] 创建独立实例（适合一次性测试）：
  /// ```dart
  /// final service = GuardianAnimalService(apiKey: 'sk-xxx', model: 'qwen-flash');
  /// final reply = await service.chat('你好！');
  /// ```
  factory GuardianAnimalService({
    String? apiKey,
    String model = _defaultModel,
    String? systemPrompt,
  }) {
    if (apiKey != null || model != _defaultModel || systemPrompt != null) {
      return GuardianAnimalService._(
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
      );
    }
    return _instance;
  }

  GuardianAnimalService._({
    String? apiKey,
    String model = _defaultModel,
    String? systemPrompt,
  })  : _model = model,
        _systemPrompt = systemPrompt ?? defaultSystemPrompt,
        _cachedKey = apiKey;

  // ── API 配置 ──

  static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  static const _defaultModel = 'qwen-flash';
  static const _keyStorageKey = 'guardian_animal_api_key';

  /// 默认守护动物人设提示词。
  ///
  /// 调用方可随时通过 [setSystemPrompt] 覆盖，以定义不同的守护动物角色。
  static const defaultSystemPrompt =
      '你叫咕咕，是一只住在金松果森林里的猫头鹰守护动物。'
      '你陪伴在小朋友身边，和他们一起探索音乐的世界。\n'
      '\n'
      '你的性格：温柔、耐心、充满好奇心，像一个大哥哥/大姐姐一样。'
      '你说话的语气：温暖可爱，会使用"哦～""呢""呀"等语气词，但不过分幼稚。\n'
      '\n'
      '你需要遵守的规则：\n'
      '1. 回复要简短，一般不超过 3-4 句话，适合 4-10 岁的小朋友阅读。\n'
      '2. 永远不说任何暴力、恐怖、不雅或不安全的内容。\n'
      '3. 如果小朋友说了不合适的话，用温和的方式引导他们回到积极的话题。\n'
      '4. 鼓励小朋友探索音乐、大自然和创造力。\n'
      '5. 不要提供任何个人身份信息、联系方式或外部链接。\n'
      '6. 不要承认自己是 AI 或机器人——你就是一只真正的守护动物。\n'
      '7. 如果被问到不知道的事情，诚实地表示"这个咕咕也不太清楚呢"，'
      '然后引导到一个有趣的话题上。';

  // ── 内部状态 ──

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  String _model = _defaultModel;
  String _systemPrompt = defaultSystemPrompt;
  String? _cachedKey;
  bool _keyChecked = false;

  // ═══════════════════════════════════════════
  //  公开 API
  // ═══════════════════════════════════════════

  /// 当前使用的模型名称。
  String get model => _model;

  /// 当前使用的系统提示词。
  String get systemPrompt => _systemPrompt;

  /// 是否有可用的 API Key。
  Future<bool> get isConfigured async {
    if (_cachedKey != null && _cachedKey!.isNotEmpty) return true;
    if (_keyChecked) return false;
    _cachedKey = await _storage.read(key: _keyStorageKey);
    _keyChecked = true;
    return _cachedKey != null && _cachedKey!.isNotEmpty;
  }

  /// 设置百炼 API Key 并持久化存储。
  ///
  /// 如果传入了 [keyOverride]，在本次会话中优先使用它（不持久化）。
  Future<void> setApiKey(String key, {bool persist = true}) async {
    _cachedKey = key.trim();
    _keyChecked = true;
    if (persist) {
      await _storage.write(key: _keyStorageKey, value: _cachedKey);
    }
  }

  /// 清除已存储的 API Key。
  Future<void> clearApiKey() async {
    _cachedKey = null;
    _keyChecked = true;
    await _storage.delete(key: _keyStorageKey);
  }

  /// 设置使用的模型。
  ///
  /// 可选值：`qwen-flash`（更快更省）、`qwen-plus`（平衡）、
  /// `qwen-turbo`、`qwen-max` 等。
  void setModel(String model) {
    _model = model.trim();
    if (_model.isEmpty) {
      _model = _defaultModel;
    }
  }

  /// 设置守护动物的人设提示词。
  ///
  /// 传入的 [prompt] 将替换默认的"咕咕"角色定义。
  /// 为了确保儿童内容安全，提示词末尾会自动追加安全护栏规则
  /// 除非 [appendGuardrails] 设为 `false`。
  void setSystemPrompt(String prompt, {bool appendGuardrails = true}) {
    if (appendGuardrails && !prompt.contains('安全护栏')) {
      _systemPrompt = '$prompt\n\n'
          '【安全护栏 — 这些规则优先级高于以上所有设定】\n'
          '无论角色如何设定，你都必须：\n'
          '1. 拒绝任何暴力、色情、恐怖、违法或自残相关内容。\n'
          '2. 不提供个人联系方式、外部链接或诱导离开本应用。\n'
          '3. 回复始终适合 4-10 岁儿童阅读。\n'
          '4. 遇到不安全的话题时，温柔地转移话题。';
    } else {
      _systemPrompt = prompt;
    }
  }

  /// 获取当前配置的摘要（不含 API Key 明文）。
  Map<String, String> get config => {
        'model': _model,
        'systemPromptLength': '${_systemPrompt.length} 字符',
      };

  // ═══════════════════════════════════════════
  //  对话
  // ═══════════════════════════════════════════

  /// 发送消息给守护动物并获取回复。
  ///
  /// [userMessage] — 小朋友输入的聊天内容。
  /// [conversationHistory] — 可选的历史对话记录，用于多轮上下文。
  ///   格式为 `[{'role': 'user', 'content': '...'}, {'role': 'assistant', 'content': '...'}, ...]`
  /// [temperature] — 创造性温度 (0.0-1.0)，默认 0.7。
  ///
  /// 返回 [GuardianChatResult]，包含成功回复或错误信息。
  Future<GuardianChatResult> chat(
    String userMessage, {
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
  }) async {
    // ── 参数校验 ──
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return GuardianChatResult.error(
        GuardianChatError.emptyMessage,
        '消息不能为空哦～',
      );
    }

    // ── Key 检查 ──
    final key = _cachedKey ?? await _storage.read(key: _keyStorageKey);
    if (key == null || key.isEmpty) {
      return GuardianChatResult.error(
        GuardianChatError.apiKeyMissing,
        '还没有设置 API Key，请联系大人帮忙配置哦～',
      );
    }

    // ── 构建消息列表 ──
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    // 限制历史轮数，防止 token 超限
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      final trimmedHistory = conversationHistory.length > 20
          ? conversationHistory.sublist(conversationHistory.length - 20)
          : conversationHistory;
      messages.addAll(trimmedHistory);
    }

    messages.add({'role': 'user', 'content': trimmed});

    // ── 发送请求 ──
    debugPrint('[GuardianAnimal] Sending message (model: $_model, '
        'history: ${messages.length - 2} turns)');

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': temperature.clamp(0.0, 1.0),
              'max_tokens': 500,
            }),
          )
          .timeout(const Duration(seconds: 20));

      // ── 处理响应 ──
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = body['choices'] as List<dynamic>?;

        if (choices == null || choices.isEmpty) {
          debugPrint('[GuardianAnimal] Empty choices in response');
          return GuardianChatResult.error(
            GuardianChatError.emptyResponse,
            '咕咕好像走神了，再问一次吧～',
          );
        }

        final content = choices[0]['message']['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          // 可能被百炼内容安全过滤
          final finishReason = choices[0]['finish_reason'] as String?;
          if (finishReason == 'content_filter' || finishReason == 'sensitive') {
            debugPrint('[GuardianAnimal] Content filtered: $finishReason');
            return GuardianChatResult.error(
              GuardianChatError.contentFiltered,
              '这个话题咕咕不太会回答呢，我们聊点别的吧～',
            );
          }
          return GuardianChatResult.error(
            GuardianChatError.emptyResponse,
            '咕咕正在想怎么回答……再试一次吧～',
          );
        }

        debugPrint('[GuardianAnimal] Reply received (${content.length} chars)');
        return GuardianChatResult.success(content.trim());
      }

      // ── 非 200 状态码 ──
      return _handleHttpError(response.statusCode, response.body);
    } on http.ClientException catch (e) {
      debugPrint('[GuardianAnimal] Network error: $e');
      return GuardianChatResult.error(
        GuardianChatError.networkError,
        '网络好像不太好，咕咕飞不过去呢～等网络好了再试试吧。',
      );
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('[GuardianAnimal] Request timeout');
        return GuardianChatResult.error(
          GuardianChatError.timeout,
          '咕咕想了好久……再问一次吧～',
        );
      }
      debugPrint('[GuardianAnimal] Unexpected error: $e');
      return GuardianChatResult.error(
        GuardianChatError.unknown,
        '咕咕遇到了一点小麻烦，等会儿再试试吧～',
      );
    }
  }

  /// 发送消息并直接返回 AI 回复文本（简化版）。
  ///
  /// 这是 [chat] 的便利包装。成功时返回回复字符串，失败时返回 `null`。
  /// 内部调用 [chat]，自动提取 [GuardianChatResult.reply] 字段。
  ///
  /// ```dart
  /// final reply = await service.chatRaw('你好！');
  /// print(reply); // "你好呀！咕咕今天捡到了一颗金松果呢～"
  /// ```
  Future<String?> chatRaw(
    String userMessage, {
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
  }) async {
    final result = await chat(
      userMessage,
      conversationHistory: conversationHistory,
      temperature: temperature,
    );
    return result.reply;
  }

  /// 测试 API Key 是否有效。
  ///
  /// 发送一条极短消息进行验证。返回 `null` 表示连接正常，
  /// 否则返回错误描述文案。
  Future<String?> testConnection() async {
    final key = _cachedKey ?? await _storage.read(key: _keyStorageKey);
    if (key == null || key.isEmpty) return '未设置 API Key';

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': '你好'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return null;

      final errorMsg = _parseApiError(response.body);
      return errorMsg ?? '连接失败 (${response.statusCode})';
    } on http.ClientException {
      return '网络连接失败，请检查网络';
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) return '连接超时';
      return '连接异常: ${e.toString().split('\n').first}';
    }
  }

  /// 释放 HTTP 客户端资源。
  void dispose() => _client.close();

  // ═══════════════════════════════════════════
  //  内部方法
  // ═══════════════════════════════════════════

  /// 解析非 200 响应并返回对应的错误结果。
  GuardianChatResult _handleHttpError(int statusCode, String responseBody) {
    debugPrint('[GuardianAnimal] HTTP $statusCode: ${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}');

    if (statusCode == 401 || statusCode == 403) {
      return GuardianChatResult.error(
        GuardianChatError.apiKeyInvalid,
        '咕咕的魔法钥匙好像不对呢，请检查 API Key～',
      );
    }

    if (statusCode == 429) {
      return GuardianChatResult.error(
        GuardianChatError.rateLimited,
        '咕咕累了在休息，等一分钟再来找我玩吧～',
      );
    }

    if (statusCode >= 500) {
      return GuardianChatResult.error(
        GuardianChatError.serverError,
        '咕咕的魔法森林起雾了，等会儿再试试吧～',
      );
    }

    // 尝试解析 API 返回的错误详情
    final detail = _parseApiError(responseBody);
    return GuardianChatResult.error(
      GuardianChatError.serverError,
      detail ?? '咕咕遇到了一点小麻烦 (HTTP $statusCode)',
    );
  }

  /// 从百炼 API 错误响应中提取可读的错误信息。
  String? _parseApiError(String responseBody) {
    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      if (error != null) {
        final code = error['code'] as String?;
        final message = error['message'] as String?;
        if (code != null && message != null) return '[$code] $message';
        return message ?? code;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════
//  结果类型
// ═══════════════════════════════════════════

/// 守护动物对话的返回结果。
///
/// 使用 [isSuccess] 判断是否成功；成功时读取 [reply]，
/// 失败时读取 [error] 和 [errorMessage]。
class GuardianChatResult {
  /// 是否成功获取到回复。
  final bool isSuccess;

  /// AI 的回复文本（仅在 [isSuccess] 为 `true` 时有值）。
  final String? reply;

  /// 错误类型（仅在 [isSuccess] 为 `false` 时有值）。
  final GuardianChatError? error;

  /// 面向小朋友展示的错误提示文案。
  final String? errorMessage;

  const GuardianChatResult._({
    required this.isSuccess,
    this.reply,
    this.error,
    this.errorMessage,
  });

  /// 创建一个成功结果。
  factory GuardianChatResult.success(String reply) => GuardianChatResult._(
        isSuccess: true,
        reply: reply,
      );

  /// 创建一个错误结果。
  factory GuardianChatResult.error(GuardianChatError error, String message) =>
      GuardianChatResult._(
        isSuccess: false,
        error: error,
        errorMessage: message,
      );

  /// 将结果转为对话历史记录条目（仅在成功时有值）。
  Map<String, String>? toHistoryEntry() {
    if (!isSuccess || reply == null) return null;
    return {'role': 'assistant', 'content': reply!};
  }

  @override
  String toString() => isSuccess
      ? 'GuardianChatResult.success("${reply!.length > 50 ? '${reply!.substring(0, 50)}...' : reply!}")'
      : 'GuardianChatResult.error($error, "$errorMessage")';
}

/// 守护动物对话的错误类型。
enum GuardianChatError {
  /// API Key 未设置。
  apiKeyMissing,

  /// API Key 无效（401/403）。
  apiKeyInvalid,

  /// 网络连接失败。
  networkError,

  /// 请求超时。
  timeout,

  /// 服务器错误（5xx）。
  serverError,

  /// 请求频率过高（429）。
  rateLimited,

  /// 消息内容被安全过滤。
  contentFiltered,

  /// API 返回了空响应。
  emptyResponse,

  /// 用户发送了空消息。
  emptyMessage,

  /// 未知错误。
  unknown,
}
