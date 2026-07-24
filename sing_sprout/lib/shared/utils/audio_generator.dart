import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/file_storage_service.dart';

/// 简易音频生成工具
///
/// MVP 阶段 AI 生成未接入前，为作品生成可听的测试音频，
/// 确保播放功能端到端可用。
class AudioGenerator {
  /// 生成一段简单的 WAV 音频并写入文件，返回文件路径。
  ///
  /// [styleSeed] 影响音高频率，让不同风格有不同听感。
  static Future<String> generateTestTone({
    required String styleSeed,
    double durationSec = 3.0,
  }) async {
    const sampleRate = 44100;
    const numChannels = 1;
    const bitsPerSample = 16;

    final numSamples = (sampleRate * durationSec).round();
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 44 + dataSize;

    // 根据 styleSeed 选择基频（模拟不同风格的感觉）
    double baseFreq;
    switch (styleSeed) {
      case 'morningDew':
        baseFreq = 523.25; // C5 — 清晨明亮
        break;
      case 'nightBreeze':
        baseFreq = 329.63; // E4 — 夜晚柔和
        break;
      case 'rainDrops':
        baseFreq = 440.0; // A4 — 雨滴清脆
        break;
      case 'birdSong':
        baseFreq = 659.25; // E5 — 鸟鸣高亢
        break;
      default:
        baseFreq = 440.0;
    }

    // 生成简单的三音旋律
    final frequencies = [
      baseFreq,
      baseFreq * 1.25, // 大三度
      baseFreq * 1.5,  // 五度
    ];

    final bytes = ByteData(fileSize);

    // ── WAV 头 ──
    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    bytes.setUint32(4, fileSize - 8, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeString(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    // ── 音频数据 ──
    final notesPerNote = numSamples ~/ frequencies.length;
    for (var i = 0; i < numSamples; i++) {
      final noteIndex = (i ~/ notesPerNote).clamp(0, frequencies.length - 1);
      final freq = frequencies[noteIndex];
      // 轻微淡入淡出
      final envelope = _envelope(i, numSamples);
      final sample = (sin(2 * pi * freq * i / sampleRate) * envelope * 0.7 * 32767).round();
      bytes.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
    }

    // 写入文件
    final storage = FileStorageService();
    final path = storage.generateMusicPath(styleSeed: styleSeed);
    await storage.saveBytes(path, bytes.buffer.asUint8List());

    debugPrint('[AudioGenerator] 测试音频已生成: $path (${durationSec}s, ${freqToLabel(baseFreq)})');
    return path;
  }

  static double _envelope(int i, int total) {
    const fadeLen = 2205; // 50ms at 44100Hz
    if (i < fadeLen) return i / fadeLen;
    if (i > total - fadeLen) return (total - i) / fadeLen;
    return 1.0;
  }

  static String freqToLabel(double hz) {
    final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final midi = (12 * (log(hz / 440) / ln2) + 69).round();
    if (midi < 0 || midi > 127) return '$hz Hz';
    return '${notes[midi % 12]}${midi ~/ 12 - 1} ($hz Hz)';
  }
}
