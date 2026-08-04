import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/music_work.dart';
import '../models/sound_sample.dart';
import '../models/voice_card.dart';
import '../models/user_profile.dart';

/// 本地数据导出服务
///
/// 将所有创作数据打包为 ZIP 文件，包含作品、声音、明信片、用户档案的
/// JSON 数据 + 关联音频文件和封面图。
class ExportService {
  /// 导出所有本地数据为 ZIP 文件，返回文件路径
  static Future<String> exportAll({
    required List<MusicWork> works,
    required List<SoundSample> sounds,
    required List<VoiceCard> cards,
    required UserProfile? profile,
  }) async {
    final archive = Archive();

    // 1. JSON 数据文件
    final worksJson = json.encode(works.map((w) => w.toJson()).toList());
    archive.addFile(ArchiveFile('works.json', utf8.encode(worksJson).length,
        utf8.encode(worksJson),),);

    final soundsJson = json.encode(sounds.map((s) => s.toJson()).toList());
    archive.addFile(ArchiveFile('sounds.json', utf8.encode(soundsJson).length,
        utf8.encode(soundsJson),),);

    final cardsJson = json.encode(cards.map((c) => _cardToJson(c)).toList());
    archive.addFile(ArchiveFile('cards.json', utf8.encode(cardsJson).length,
        utf8.encode(cardsJson),),);

    if (profile != null) {
      final profileJson = json.encode(_profileToJson(profile));
      archive.addFile(ArchiveFile('profile.json',
          utf8.encode(profileJson).length, utf8.encode(profileJson),),);
    }

    // 2. 音频文件和封面图
    for (final w in works) {
      final audioFile = File(w.audioPath);
      if (await audioFile.exists()) {
        final bytes = await audioFile.readAsBytes();
        final name = 'audio/${_safeName(w.title)}_${w.id.substring(0, 8)}.m4a';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
      if (w.coverPath != null) {
        final coverFile = File(w.coverPath!);
        if (await coverFile.exists()) {
          final bytes = await coverFile.readAsBytes();
          final ext = w.coverPath!.split('.').last;
          final name =
              'covers/${_safeName(w.title)}_${w.id.substring(0, 8)}.$ext';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
    }
    for (final s in sounds) {
      final file = File(s.audioPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final name = 'audio/sound_${s.id.substring(0, 8)}';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    // 3. 编码为 ZIP
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('ZIP 编码失败');

    // 4. 写入文件
    final docsDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${docsDir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final zipPath = '${exportsDir.path}/singsprout_export_$timestamp.zip';
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);

    debugPrint('[ExportService] 导出完成: $zipPath (${zipData.length} bytes)');
    return zipPath;
  }

  static Map<String, dynamic> _cardToJson(VoiceCard card) => {
        'id': card.id,
        'work_id': card.workId,
        'sender_id': card.senderId,
        'recipient_id': card.recipientId,
        'text_content': card.textContent,
        'created_at': card.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _profileToJson(UserProfile p) => {
        'local_id': p.localId,
        'nickname': p.nickname,
        'guardian_animal': p.guardianAnimal.name,
        'role': p.role.name,
        'has_completed_onboarding': p.hasCompletedOnboarding,
        'created_at': p.createdAt.toIso8601String(),
      };

  static String _safeName(String name) {
    return name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }
}
