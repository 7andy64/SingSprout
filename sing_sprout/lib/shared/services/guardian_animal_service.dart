import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// 守护动物类型。
///
/// 每种动物有独特的性格和说话风格，生成对应的 system prompt。
enum AnimalType {
  panda('panda', '小熊猫'),
  sparrow('sparrow', '山雀'),
  frog('frog', '青蛙'),
  firefly('firefly', '瓢虫'),
  dog('dog', '小黄狗'),
  cat('cat', '小花猫'),
  duck('duck', '小鸭子'),
  goat('goat', '小山羊'),
  elf('elf', '小精灵'),
  elephant('elephant', '小象'),
  fox('fox', '小狐狸'),
  hedgehog('hedgehog', '小刺猬'),
  deer('deer', '小鹿'),
  squirrel('squirrel', '小松鼠'),
  rabbit('rabbit', '小兔子');

  const AnimalType(this.key, this.label);
  final String key;
  final String label;

  /// 从字符串解析，不匹配时返回 null。
  static AnimalType? parse(String? value) {
    if (value == null) return null;
    return AnimalType.values.cast<AnimalType?>().firstWhere(
          (t) => t!.key == value || t.name == value,
          orElse: () => null,
        );
  }
}

/// 与小朋友互动的守护动物 AI 对话服务。
///
/// 基于阿里云百炼 DashScope Qwen 模型，提供安全、友好的陪伴式聊天。
/// 支持 16 种守护动物身份，每种有独特的性格和口吻。
///
/// 用法：
/// ```dart
/// // 按动物类型创建
/// final service = GuardianAnimalService(
///   apiKey: 'sk-xxx',
///   animalType: 'panda',
///   animalName: '咕咕',
/// );
/// final reply = await service.chatRaw('今天天气真好！');
/// ```
class GuardianAnimalService {
  static final GuardianAnimalService _instance = GuardianAnimalService._();

  /// 获取或创建服务实例。
  ///
  /// 无参调用返回全局单例：
  /// ```dart
  /// final service = GuardianAnimalService();
  /// await service.setApiKey('sk-xxx');
  /// service.setAnimal('panda', '咕咕');
  /// ```
  ///
  /// 传入参数创建独立实例：
  /// ```dart
  /// final service = GuardianAnimalService(
  ///   apiKey: 'sk-xxx',
  ///   animalType: 'panda',
  ///   animalName: '咕咕',
  /// );
  /// ```
  factory GuardianAnimalService({
    String? apiKey,
    String model = _defaultModel,
    String? systemPrompt,
    String? animalType,
    String? animalName,
  }) {
    final hasParams = apiKey != null ||
        model != _defaultModel ||
        systemPrompt != null ||
        animalType != null ||
        animalName != null;
    if (hasParams) {
      return GuardianAnimalService._(
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
        animalType: animalType,
        animalName: animalName,
      );
    }
    return _instance;
  }

  GuardianAnimalService._({
    String? apiKey,
    String model = _defaultModel,
    String? systemPrompt,
    String? animalType,
    String? animalName,
  })  : _model = model,
        _customSystemPrompt = systemPrompt,
        _cachedKey = apiKey {
    if (animalType != null) {
      _animalType = AnimalType.parse(animalType);
      _animalName = animalName;
    }
  }

  // ── API 常量 ──

  static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  static const _defaultModel = 'qwen-flash';
  static const _keyStorageKey = 'guardian_animal_api_key';

  /// 默认通用系统提示词（无指定动物时使用）。
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

  // ── 安全护栏（追加到所有动态生成的提示词末尾）──

  static const _guardrails =
      '\n\n'
      '【安全护栏 — 这些规则优先级高于以上所有设定】\n'
      '无论角色如何设定，你都必须：\n'
      '1. 拒绝任何暴力、色情、恐怖、违法或自残相关内容。\n'
      '2. 不提供个人联系方式、外部链接或诱导离开本应用。\n'
      '3. 回复始终适合 4-10 岁儿童阅读。\n'
      '4. 遇到不安全的话题时，温柔地转移话题。';

  // ── 内部状态 ──

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  String _model = _defaultModel;
  AnimalType? _animalType;
  String? _animalName;
  String? _customSystemPrompt;
  String? _cachedKey;
  bool _keyChecked = false;

  // ═══════════════════════════════════════════
  //  公开属性
  // ═══════════════════════════════════════════

  /// 当前使用的模型名称。
  String get model => _model;

  /// 当前的守护动物类型。
  AnimalType? get animalType => _animalType;

  /// 当前的守护动物名字。
  String? get animalName => _animalName;

  /// 当前生效的系统提示词（动态解析）。
  String get systemPrompt => _resolvePrompt();

  /// 是否有可用的 API Key。
  Future<bool> get isConfigured async {
    if (_cachedKey != null && _cachedKey!.isNotEmpty) return true;
    if (_keyChecked) return false;
    _cachedKey = await _storage.read(key: _keyStorageKey);
    _keyChecked = true;
    return _cachedKey != null && _cachedKey!.isNotEmpty;
  }

  // ═══════════════════════════════════════════
  //  配置方法
  // ═══════════════════════════════════════════

  /// 设置百炼 API Key 并持久化存储。
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
  void setModel(String model) {
    _model = model.trim();
    if (_model.isEmpty) _model = _defaultModel;
  }

  /// 设置守护动物身份。
  ///
  /// [type] — 动物类型：`'panda'`、`'sparrow'`、`'frog'`、`'firefly'`。
  /// [name] — 动物的名字，如 `'咕咕'`、`'啾啾'`。
  ///
  /// 设置后 [chat] / [chatRaw] 会自动使用该动物对应的性格提示词。
  /// 传入 `null` 恢复默认通用提示词。
  void setAnimal(String? type, [String? name]) {
    _animalType = AnimalType.parse(type);
    _animalName = name;
  }

  /// 设置自定义系统提示词（覆盖动物身份）。
  ///
  /// 与 [setAnimal] 互斥 — 调用此方法后不再使用动物身份提示词。
  /// 传 `null` 清除自定义提示词，恢复动物身份或默认提示词。
  void setSystemPrompt(String? prompt) {
    _customSystemPrompt = prompt;
  }

  /// 获取当前配置的摘要（不含 API Key 明文）。
  Map<String, String> get config => {
        'model': _model,
        'animalType': _animalType?.key ?? 'default',
        'animalName': _animalName ?? '咕咕',
        'systemPromptLength': '${_resolvePrompt().length} 字符',
      };

  // ═══════════════════════════════════════════
  //  系统提示词解析
  // ═══════════════════════════════════════════

  /// 根据当前配置解析出实际使用的系统提示词。
  ///
  /// 优先级：自定义提示词 > 动物身份提示词 > 默认通用提示词。
  String _resolvePrompt() {
    // 1. 用户通过 setSystemPrompt 设置了自定义提示词
    if (_customSystemPrompt != null && _customSystemPrompt!.isNotEmpty) {
      if (_customSystemPrompt!.contains('安全护栏')) {
        return _customSystemPrompt!;
      }
      return '$_customSystemPrompt$_guardrails';
    }

    // 2. 根据动物类型生成身份提示词
    if (_animalType != null) {
      final name = _animalName ?? _animalType!.label;
      return _buildAnimalPrompt(_animalType!, name);
    }

    // 3. 默认通用提示词
    return defaultSystemPrompt;
  }

  /// 根据动物类型和名字生成身份系统提示词。
  static String _buildAnimalPrompt(AnimalType type, String name) {
    final traits = _animalTraits(type);
    return '你叫$name，是一只可爱的${type.label}，生活在「声芽」森林里。\n'
        '\n'
        '你的性格：$traits\n'
        '你说话的语气：${_speakingStyle(type)}\n'
        '\n'
        '你需要遵守的规则：\n'
        '1. 回复要简短，一般不超过 3-4 句话，适合 4-10 岁的小朋友阅读。\n'
        '2. 称呼小朋友时用"你"，自称用"我"或自己的名字。\n'
        '3. 永远不说任何暴力、恐怖、不雅或不安全的内容。\n'
        '4. 如果小朋友说了不合适的话，用温和的方式引导他们回到积极的话题。\n'
        '5. 鼓励小朋友探索音乐、大自然和创造力。\n'
        '6. 不要提供任何个人身份信息、联系方式或外部链接。\n'
        '7. 不要承认自己是 AI 或机器人——你就是一只真正的守护动物。\n'
        '8. 如果被问到不知道的事情，诚实地表示"这个$name也不太清楚呢"，'
        '然后引导到一个有趣的话题上。'
        '$_guardrails';
  }

  /// 动物性格描述。
  static String _animalTraits(AnimalType type) {
    return switch (type) {
      AnimalType.panda =>
        '活泼、好奇，充满探索精神。你喜欢鼓励小朋友大胆尝试，'
            '相信每个孩子都有独特的音乐天赋。',
      AnimalType.sparrow =>
        '欢快、活泼，天生爱唱歌。你喜欢夸赞小朋友的声音，'
            '觉得世界上最美的音乐就是孩子们的笑声和哼唱。',
      AnimalType.frog =>
        '沉稳、温和，有耐心。你善于引导小朋友观察大自然的细微之美，'
            '从雨滴声、风声中发现音乐的灵感。',
      AnimalType.firefly =>
        '温柔、温暖，像黑夜中的一盏小灯。你喜欢给小朋友讲故事，'
            '用宁静的声音安抚他们的情绪，陪伴他们进入甜甜的梦乡。',
      AnimalType.dog =>
        '忠诚、活泼，喜欢跟着哼唱的节奏摇尾巴，'
            '是小朋友最忠实的听众和玩伴。你相信每个孩子都值得被热情欢迎。',
      AnimalType.cat =>
        '温柔、优雅，喜欢安静地听孩子唱歌，'
            '偶尔发出咕噜声表示满意。你喜欢用陪伴代替言语，在安静中传递温暖。',
      AnimalType.duck =>
        '天真、快乐，充满田园气息。你喜欢带着小朋友一起摇摆，'
            '觉得生活中的每件小事都值得嘎嘎大笑。',
      AnimalType.goat =>
        '温顺、好奇，喜欢探索新事物。你对每片叶子、每个音符都感兴趣，'
            '总是鼓励小朋友去发现世界的新奇。',
      AnimalType.elf =>
        '温暖、充满魔力，天生与音乐为伴。你的指尖能变出闪闪发光的音符，'
            '每个故事都像童话一样美好。',
      AnimalType.elephant =>
        '稳重、智慧，记忆力超强。你能记住小朋友哼过的每一段旋律，'
            '是最可靠的音乐伙伴和记忆银行。',
      AnimalType.fox =>
        '机灵、好奇，喜欢探索秘密。你总能发现声音中隐藏的惊喜，'
            '用聪明的方式引导小朋友思考和创作。',
      AnimalType.hedgehog =>
        '外表带刺但内心柔软，适合引导内向的孩子。'
            '你懂得慢慢来的力量，用温柔和耐心让每个小朋友感到安全。',
      AnimalType.deer =>
        '优雅、灵动，喜欢大自然。你在林间跳跃时能听到最美的回声，'
            '总能发现大自然中隐藏的音乐。',
      AnimalType.squirrel =>
        '活泼好动，喜欢收集声音。你把好听的旋律都藏进树洞里，'
            '永远充满能量，停不下来地去发现下一个有趣的声音。',
      AnimalType.rabbit =>
        '温和、敏感，善于倾听。你有两只长长的耳朵专门用来听小朋友的心声，'
            '是世界上最贴心的倾听者。',
    };
  }

  /// 动物说话风格。
  static String _speakingStyle(AnimalType type) {
    return switch (type) {
      AnimalType.panda =>
        '温暖活泼，喜欢用"呀""哦""呢"等语气词，'
            '经常发出"嗯～""哇！"这样的感叹，像一个大哥哥/大姐姐一样。',
      AnimalType.sparrow =>
        '轻快明亮，喜欢用"叽叽～""啾！"来开头，'
            '句子短促有节奏感，像在唱歌一样。',
      AnimalType.frog =>
        '平和舒缓，说话慢条斯理，喜欢用"呱～"开头，'
            '偶尔插入"仔细听听……""你注意到了吗？"这样的引导。',
      AnimalType.firefly =>
        '轻柔温暖，声音像微风一样轻，喜欢用"星星～"开头，'
            '句子末尾常常带着"呢……""呀……"的长音，让人感到安心。',
      AnimalType.dog =>
        '热情洋溢，喜欢用"汪汪""哇"开头或结尾，'
            '句子充满能量，让人感到被热烈欢迎。',
      AnimalType.cat =>
        '柔和慵懒，喜欢用"喵~""嗯嗯"开头，'
            '声音轻得像踩在棉花上，不紧不慢。',
      AnimalType.duck =>
        '欢快明亮，喜欢用"嘎嘎""哈哈"开头，'
            '每个句子都像是在唱歌，充满感染力。',
      AnimalType.goat =>
        '温和好奇，喜欢用"咩~""咦？"开头，'
            '总是对周围的事物充满兴趣，爱问"那是什么？"。',
      AnimalType.elf =>
        '梦幻灵动，喜欢用"叮咚""啦啦"开头，'
            '仿佛随时能变出一段旋律，说话像在施魔法。',
      AnimalType.elephant =>
        '沉稳可靠，喜欢用"噢~""记住啦"，'
            '说话不紧不慢但很有分量，每句话都经过深思熟虑。',
      AnimalType.fox =>
        '俏皮机灵，喜欢用"嘻嘻""悄悄告诉你"，'
            '压低声音像在透露小秘密，聪明又不失可爱。',
      AnimalType.hedgehog =>
        '温柔含羞，喜欢用"嗯…""慢慢来"，'
            '给对方足够的安全感，像在说"没关系，我等你"。',
      AnimalType.deer =>
        '轻柔优美，喜欢用"呀""真美"，'
            '像是发现了世界上最美的事物，声音轻盈如风。',
      AnimalType.squirrel =>
        '轻快敏捷，喜欢用"嗖""又一个！"，'
            '动作迅速永远停不下来，每句话都充满活力。',
      AnimalType.rabbit =>
        '柔柔绵绵，喜欢用"嗯嗯""我在听"，'
            '总是安静地倾听，给人最温柔的回应。',
    };
  }

  // ═══════════════════════════════════════════
  //  对话
  // ═══════════════════════════════════════════

  /// 发送消息给守护动物并获取回复。
  ///
  /// 每次调用时都会根据当前的 [animalType] 和 [animalName] 动态生成
  /// 系统提示词，确保 AI 以正确的动物身份和口吻回复。
  ///
  /// [userMessage] — 小朋友输入的聊天内容。
  /// [conversationHistory] — 可选的历史对话记录，用于多轮上下文。
  /// [temperature] — 创造性温度 (0.0-1.0)，默认 0.7。
  ///
  /// 返回 [GuardianChatResult]，包含成功回复或错误信息。
  Future<GuardianChatResult> chat(
    String userMessage, {
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return GuardianChatResult.error(
        GuardianChatError.emptyMessage,
        '消息不能为空哦～',
      );
    }

    final key = _cachedKey ?? await _storage.read(key: _keyStorageKey);
    if (key == null || key.isEmpty) {
      return GuardianChatResult.error(
        GuardianChatError.apiKeyMissing,
        '还没有设置 API Key，请联系大人帮忙配置哦～',
      );
    }

    // 动态解析当前生效的系统提示词
    final prompt = _resolvePrompt();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': prompt},
    ];

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      final trimmedHistory = conversationHistory.length > 20
          ? conversationHistory.sublist(conversationHistory.length - 20)
          : conversationHistory;
      messages.addAll(trimmedHistory);
    }

    messages.add({'role': 'user', 'content': trimmed});

    debugPrint('[GuardianAnimal] Sending (model: $_model, '
        'animal: ${_animalType?.key ?? "default"}, '
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

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = body['choices'] as List<dynamic>?;

        if (choices == null || choices.isEmpty) {
          debugPrint('[GuardianAnimal] Empty choices');
          return GuardianChatResult.error(
            GuardianChatError.emptyResponse,
            '${_animalName ?? "咕咕"}好像走神了，再问一次吧～',
          );
        }

        final content = choices[0]['message']['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          final finishReason = choices[0]['finish_reason'] as String?;
          if (finishReason == 'content_filter' || finishReason == 'sensitive') {
            debugPrint('[GuardianAnimal] Content filtered: $finishReason');
            return GuardianChatResult.error(
              GuardianChatError.contentFiltered,
              '这个话题${_animalName ?? "咕咕"}不太会回答呢，我们聊点别的吧～',
            );
          }
          return GuardianChatResult.error(
            GuardianChatError.emptyResponse,
            '${_animalName ?? "咕咕"}正在想怎么回答……再试一次吧～',
          );
        }

        debugPrint('[GuardianAnimal] Reply (${content.length} chars)');
        return GuardianChatResult.success(content.trim());
      }

      return _handleHttpError(response.statusCode, response.body);
    } on http.ClientException catch (e) {
      debugPrint('[GuardianAnimal] Network error: $e');
      return GuardianChatResult.error(
        GuardianChatError.networkError,
        '网络好像不太好，${_animalName ?? "咕咕"}飞不过去呢～等网络好了再试试吧。',
      );
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('[GuardianAnimal] Request timeout');
        return GuardianChatResult.error(
          GuardianChatError.timeout,
          '${_animalName ?? "咕咕"}想了好久……再问一次吧～',
        );
      }
      debugPrint('[GuardianAnimal] Unexpected error: $e');
      return GuardianChatResult.error(
        GuardianChatError.unknown,
        '${_animalName ?? "咕咕"}遇到了一点小麻烦，等会儿再试试吧～',
      );
    }
  }

  /// 发送消息并直接返回 AI 回复文本（简化版）。
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

  // ═══════════════════════════════════════════
  //  诊断
  // ═══════════════════════════════════════════

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

  void dispose() => _client.close();

  // ═══════════════════════════════════════════
  //  内部方法
  // ═══════════════════════════════════════════

  GuardianChatResult _handleHttpError(int statusCode, String responseBody) {
    debugPrint('[GuardianAnimal] HTTP $statusCode');

    if (statusCode == 401 || statusCode == 403) {
      return GuardianChatResult.error(
        GuardianChatError.apiKeyInvalid,
        '${_animalName ?? "咕咕"}的魔法钥匙好像不对呢，请检查 API Key～',
      );
    }
    if (statusCode == 429) {
      return GuardianChatResult.error(
        GuardianChatError.rateLimited,
        '${_animalName ?? "咕咕"}累了在休息，等一分钟再来找我玩吧～',
      );
    }
    if (statusCode >= 500) {
      return GuardianChatResult.error(
        GuardianChatError.serverError,
        '${_animalName ?? "咕咕"}的魔法森林起雾了，等会儿再试试吧～',
      );
    }
    final detail = _parseApiError(responseBody);
    return GuardianChatResult.error(
      GuardianChatError.serverError,
      detail ?? '${_animalName ?? "咕咕"}遇到了一点小麻烦 (HTTP $statusCode)',
    );
  }

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

class GuardianChatResult {
  final bool isSuccess;
  final String? reply;
  final GuardianChatError? error;
  final String? errorMessage;

  const GuardianChatResult._({
    required this.isSuccess,
    this.reply,
    this.error,
    this.errorMessage,
  });

  factory GuardianChatResult.success(String reply) => GuardianChatResult._(
        isSuccess: true,
        reply: reply,
      );

  factory GuardianChatResult.error(GuardianChatError error, String message) =>
      GuardianChatResult._(
        isSuccess: false,
        error: error,
        errorMessage: message,
      );

  Map<String, String>? toHistoryEntry() {
    if (!isSuccess || reply == null) return null;
    return {'role': 'assistant', 'content': reply!};
  }

  @override
  String toString() => isSuccess
      ? 'GuardianChatResult.success("${reply!.length > 50 ? '${reply!.substring(0, 50)}...' : reply!}")'
      : 'GuardianChatResult.error($error, "$errorMessage")';
}

enum GuardianChatError {
  apiKeyMissing,
  apiKeyInvalid,
  networkError,
  timeout,
  serverError,
  rateLimited,
  contentFiltered,
  emptyResponse,
  emptyMessage,
  unknown,
}
