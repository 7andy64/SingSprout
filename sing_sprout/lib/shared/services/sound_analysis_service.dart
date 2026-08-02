import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dash_scope_service.dart';
import 'sound_classification_service.dart';
import '../../core/constants/enums.dart';

/// 田野声音 AI 分析服务（文本路径）
///
/// 使用阿里云 DashScope (qwen-plus) 对录制的声音样本进行智能分析。
/// 注意：此服务发送的是文件元数据而非音频数据。
/// 推荐使用 [SoundClassificationService] 进行真实的音频分类。
class SoundAnalysisService {
  final DashScopeService _dashScope = DashScopeService();

  static const _analysisPrompt = '''
你是一个儿童音乐启蒙应用的声音分析助手，专门为 9-12 岁乡村儿童分析他们采集的田野声音。

用户录制了一段声音，请你分析并给出对孩子友好的结果。

请严格返回以下 JSON 格式（不要 markdown 包裹，不要有其他文字）：

{
  "type": "nature",
  "estimated_bpm": 72,
  "description": "清脆的鸟鸣声，像春天早晨的问候",
  "recommended_use": "这个声音适合做背景环境音，搭配钢琴旋律效果很好，试试放在乐曲的开头作为引子"
}

规则：
- type: 只能是 "humanVoice"(人声)、"animal"(动物)、"nature"(自然)、"mechanical"(机械) 之一
- estimated_bpm: 估计的节拍速度，范围 40-180
- description: 用孩子能理解的、有画面感的语言描述这个声音（20字以内）
- recommended_use: 给孩子的创意建议，告诉他们怎么用这个声音来创作音乐（40字以内）

声音分类参考：
- 人声: 说话、唱歌、笑声、喊叫等
- 动物: 鸟叫、虫鸣、猫狗叫声、蛙鸣等
- 自然: 风声、雨声、水流、树叶沙沙等
- 机械: 铃声、敲击声、车辆声、工具声等
- 如果难以判断，选择最接近的一种

请发挥创意，让分析结果温暖、有趣，激发孩子的音乐创作热情。''';

  /// 分析一段录制的声音
  ///
  /// [wavFilePath] — WAV 录音文件路径
  /// [recordingContext] — 额外的上下文信息（录制时间等）
  ///
  /// 返回 [SoundAnalysisResult] 或 null（分析失败时）
  Future<SoundAnalysisResult?> analyze(
    String wavFilePath, {
    String? recordingContext,
  }) async {
    // 检查 API Key 是否配置
    if (!await _dashScope.isConfigured) {
      debugPrint('[SoundAnalysis] DashScope API Key 未配置，回退到模拟分析');
      return null;
    }

    // 获取录音文件基本信息
    final file = File(wavFilePath);
    if (!await file.exists()) {
      debugPrint('[SoundAnalysis] 录音文件不存在: $wavFilePath');
      return null;
    }

    final fileSize = await file.length();
    final durationStr = _estimateDuration(fileSize);

    // 构建用户提示
    final userPrompt = StringBuffer();
    userPrompt.writeln('请分析这段田野录音：');
    userPrompt.writeln('- 文件大小: ${(fileSize / 1024).toStringAsFixed(1)} KB');
    userPrompt.writeln('- 录音时长: $durationStr');
    if (recordingContext != null) {
      userPrompt.writeln('- 录制背景: $recordingContext');
    }
    userPrompt.writeln('\n请发挥想象力，猜测这可能是什么声音，给出有趣的分析结果。');

    try {
      final content = await _dashScope.chatCompletion(
        systemPrompt: _analysisPrompt,
        userMessage: userPrompt.toString(),
        temperature: 0.9,
        maxTokens: 400,
      );

      if (content != null) {
        return _parseResult(content);
      }
    } catch (e) {
      debugPrint('[SoundAnalysis] 请求失败: $e');
    }
    return null;
  }

  /// 解析 AI 返回的 JSON
  SoundAnalysisResult? _parseResult(String raw) {
    try {
      var jsonStr = raw.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final obj = jsonDecode(jsonStr) as Map<String, dynamic>;

      final typeStr = (obj['type'] as String?) ?? 'unknown';
      final soundType = SoundType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => SoundType.unknown,
      );

      final bpm = (obj['estimated_bpm'] as num?)?.toDouble() ?? 90.0;
      final description = (obj['description'] as String?) ?? '';
      final recommendedUse = (obj['recommended_use'] as String?) ?? '';

      return SoundAnalysisResult(
        soundType: soundType,
        bpm: bpm.clamp(40, 180),
        recommendedUse: recommendedUse,
        rawLabels: description.isNotEmpty ? [description] : [],
        confidence: 1.0,
      );
    } catch (e) {
      debugPrint('[SoundAnalysis] JSON 解析失败: $e\n原始响应: $raw');
      return null;
    }
  }

  /// 根据文件大小粗略估计录音时长
  String _estimateDuration(int fileSizeBytes) {
    // WAV 44.1kHz 16-bit mono ≈ 88KB/s
    final estimatedSec = fileSizeBytes / 88200;
    if (estimatedSec < 1) return '不到 1 秒';
    if (estimatedSec < 60) return '约 ${estimatedSec.round()} 秒';
    final min = (estimatedSec / 60).round();
    return '约 $min 分钟';
  }
}
