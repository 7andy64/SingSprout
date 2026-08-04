import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:sing_sprout/shared/services/database_service.dart';
import 'package:sing_sprout/shared/services/encryption_service.dart';
import 'package:sing_sprout/shared/services/file_storage_service.dart';
import 'package:sing_sprout/shared/repositories/work_repository.dart';
import 'package:sing_sprout/shared/repositories/sound_repository.dart';
import 'package:sing_sprout/shared/repositories/voice_card_repository.dart';
import 'package:sing_sprout/shared/repositories/user_profile_repository.dart';
import 'package:sing_sprout/shared/models/music_work.dart';
import 'package:sing_sprout/shared/models/sound_sample.dart';
import 'package:sing_sprout/shared/models/voice_card.dart';
import 'package:sing_sprout/shared/models/user_profile.dart';
import 'package:sing_sprout/core/constants/enums.dart';

/// 测试用 PathProvider 实现，使用临时目录替代真实路径。
class _FakePathProvider extends PathProviderPlatform {
  late final String _tempDir;

  _FakePathProvider() {
    _tempDir = Directory.systemTemp.createTempSync('singsprout_test_').path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempDir;

  @override
  Future<String?> getTemporaryPath() async => _tempDir;

  @override
  Future<String?> getDownloadsPath() async => _tempDir;

  @override
  Future<String?> getApplicationSupportPath() async => _tempDir;

  @override
  Future<String?> getExternalStoragePath() async => _tempDir;

  Future<List<String>?> getExternalCacheDirectories() async => [_tempDir];

  Future<List<String>?> getExternalStorageDirectories({StorageDirectory? type}) async =>
      [_tempDir];

  @override
  Future<String?> getLibraryPath() async => _tempDir;

  // 以下方法为兼容性预留，非 override
  @override
  Future<String?> getApplicationCachePath() async => _tempDir;

  Future<String?> getExternalCachePath() async => _tempDir;

  void dispose() {
    try {
      Directory(_tempDir).deleteSync(recursive: true);
    } catch (_) {}
  }
}

void main() {
  // ================================================================
  //  声芽 SingSprout — 本地存储技术基础层验证测试
  //  覆盖: Database / Encryption / FileStorage / 4×Repository
  // ================================================================

  setUpAll(() {
    // 初始化 Flutter 绑定
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock path_provider — 重定向到临时目录
    PathProviderPlatform.instance = _FakePathProvider();
    // 初始化 sqflite FFI 用于桌面/CI 测试
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    // 每个测试后清理数据库
    try {
      await DatabaseService().clearAll();
    } catch (e) {
      // 数据库已关闭（如 close 测试后），关闭数据库后重新打开以清理
      try {
        final db = await DatabaseService().database;
        await db.transaction((txn) async {
          await txn.delete('works');
          await txn.delete('sound_samples');
          await txn.delete('voice_cards');
          await txn.delete('user_profile');
        });
      } catch (_) {
        // 无法清理，可能数据库文件不可用
      }
    }
  });

  tearDownAll(() async {
    // 测试结束后关闭数据库连接
    try {
      await DatabaseService().close();
    } catch (_) {}
    // 清理 FakePathProvider 创建的临时目录
    if (PathProviderPlatform.instance is _FakePathProvider) {
      (PathProviderPlatform.instance as _FakePathProvider).dispose();
    }
  });

  // ─────────────────────────────────────────────────────────────
  //  1. DatabaseService — 数据库 & 表结构
  // ─────────────────────────────────────────────────────────────

  group('1. DatabaseService — 数据库表结构', () {
    test('创建数据库并验证 4 张表存在', () async {
      final db = await DatabaseService().database;
      expect(db.isOpen, isTrue);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toList();

      expect(names, contains('works'));
      expect(names, contains('sound_samples'));
      expect(names, contains('voice_cards'));
      expect(names, contains('user_profile'));
      expect(names.length, greaterThanOrEqualTo(4)); // 4 张用户表
    });

    test('works 表列名与 MusicWork.toJson 对齐', () async {
      final db = await DatabaseService().database;
      final cols = await db.rawQuery("PRAGMA table_info('works')");
      final colNames = cols.map((c) => c['name'] as String).toSet();

      // 验证核心列存在
      for (final expected in [
        'id', 'title', 'audio_path', 'cover_path', 'style_seed',
        'mood_color', 'note', 'duration_ms', 'is_favorite',
        'is_encrypted', 'source_module', 'created_at', 'updated_at',
      ]) {
        expect(colNames, contains(expected), reason: '缺少列: $expected');
      }
    });

    test('sound_samples 表列名与 SoundSample.toJson 对齐', () async {
      final db = await DatabaseService().database;
      final cols = await db.rawQuery("PRAGMA table_info('sound_samples')");
      final colNames = cols.map((c) => c['name'] as String).toSet();

      for (final expected in [
        'id', 'name', 'audio_path', 'type', 'bpm',
        'pitch_sequence', 'timbre_feature', 'recommended_use',
        'is_public', 'created_at',
      ]) {
        expect(colNames, contains(expected), reason: '缺少列: $expected');
      }
    });

    test('voice_cards 表列名与 VoiceCardRepository._toRow 对齐', () async {
      final db = await DatabaseService().database;
      final cols = await db.rawQuery("PRAGMA table_info('voice_cards')");
      final colNames = cols.map((c) => c['name'] as String).toSet();

      for (final expected in [
        'id', 'work_id', 'sender_id', 'recipient_id', 'audio_path',
        'text_content', 'cover_url', 'reply_to_id', 'direction',
        'created_at', 'read_at',
      ]) {
        expect(colNames, contains(expected), reason: '缺少列: $expected');
      }
    });

    test('user_profile 表列名与 UserProfileRepository._toRow 对齐', () async {
      final db = await DatabaseService().database;
      final cols = await db.rawQuery("PRAGMA table_info('user_profile')");
      final colNames = cols.map((c) => c['name'] as String).toSet();

      for (final expected in [
        'local_id', 'nickname', 'voice_baseline_path',
        'guardian_animal', 'role', 'has_completed_onboarding', 'created_at',
      ]) {
        expect(colNames, contains(expected), reason: '缺少列: $expected');
      }
    });

    test('8 个索引全部创建', () async {
      final db = await DatabaseService().database;
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
      );
      final names = indexes.map((r) => r['name'] as String).toList();

      expect(names, contains('idx_works_created_at'));
      expect(names, contains('idx_works_source_module'));
      expect(names, contains('idx_works_favorite'));
      expect(names, contains('idx_sound_samples_created_at'));
      expect(names, contains('idx_voice_cards_created_at'));
      expect(names, contains('idx_voice_cards_work_id'));
      expect(names, contains('idx_voice_cards_read_at'));
      expect(names, contains('idx_voice_cards_direction'));
      expect(names.length, greaterThanOrEqualTo(8));
    });

    test('clearAll 清空所有表', () async {
      // 先插入测试数据
      final db = await DatabaseService().database;
      await db.insert('works', {
        'id': 'test1', 'title': 'Test', 'audio_path': '/a.mp3',
        'duration_ms': 100, 'created_at': '2025-01-01', 'updated_at': '2025-01-01',
      });

      await DatabaseService().clearAll();

      final count = await db.rawQuery('SELECT COUNT(*) as c FROM works');
      expect(count.first['c'], 0);
    });

    test('close 关闭数据库连接', () async {
      final db = await DatabaseService().database;
      expect(db.isOpen, isTrue);

      await DatabaseService().close();
      expect(db.isOpen, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  2. EncryptionService — AES-256 加解密
  // ─────────────────────────────────────────────────────────────

  group('2. EncryptionService — AES-256 加解密', () {
    setUp(() async {
      await EncryptionService().initialize('test_fingerprint_12345');
    });

    test('初始化后 isInitialized == true', () {
      expect(EncryptionService().isInitialized, isTrue);
    });

    test('encryptText / decryptText 往返一致', () {
      const plain = '你好，声芽！这是一段测试明文 Hello World 123';
      final encrypted = EncryptionService().encryptText(plain);
      final decrypted = EncryptionService().decryptText(encrypted);

      expect(encrypted, isNot(equals(plain)));
      expect(decrypted, equals(plain));
    });

    test('加密相同明文产生不同密文 (随机 IV)', () {
      const plain = 'same_text';
      final c1 = EncryptionService().encryptText(plain);
      final c2 = EncryptionService().encryptText(plain);

      expect(c1, isNot(equals(c2)));
    });

    test('空字符串加解密', () {
      final encrypted = EncryptionService().encryptText('');
      final decrypted = EncryptionService().decryptText(encrypted);
      expect(decrypted, equals(''));
    });

    test('长文本加解密 (>1000 字符)', () {
      final plain = '测' * 1500;
      final encrypted = EncryptionService().encryptText(plain);
      final decrypted = EncryptionService().decryptText(encrypted);
      expect(decrypted, equals(plain));
    });

    test('encryptBytes / decryptBytes 往返一致', () {
      final bytes = List<int>.generate(256, (i) => i);
      final encrypted = EncryptionService().encryptBytes(bytes);
      final decrypted = EncryptionService().decryptBytes(encrypted);

      expect(encrypted, isNot(orderedEquals(bytes)));
      expect(decrypted, orderedEquals(bytes));
    });

    test('解密旧版 Base64 混淆数据可兼容', () {
      const plain = 'legacy_data';
      // 手动 Base64 编码（模拟未初始化时的回退）
      const base64Only =
          'bGVnYWN5X2RhdGE='; // base64("legacy_data")
      // 未初始化就直接 base64 解码
      final decrypted = EncryptionService().decryptText(base64Only);
      // 应该正确还原原文
      expect(decrypted, equals(plain));
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  3. FileStorageService — 文件系统操作
  // ─────────────────────────────────────────────────────────────

  group('3. FileStorageService — 文件系统操作', () {
    late FileStorageService fileService;

    setUp(() async {
      fileService = FileStorageService();
      await fileService.initialize();
    });

    test('初始化后 rootPath 不为空', () {
      expect(fileService.rootPath, isNotEmpty);
    });

    test('4 个子目录存在', () async {
      for (final dir in [
        fileService.recordingsDir,
        fileService.generatedDir,
        fileService.coversDir,
        fileService.exportsDir,
      ]) {
        expect(await Directory(dir).exists(), isTrue,
            reason: '$dir 应存在',);
      }
    });

    test('saveBytes → readBytes 往返一致', () async {
      final path = fileService.generateRecordingPath();
      final data = List<int>.generate(100, (i) => i % 256);

      final savedPath = await fileService.saveBytes(path, data);
      expect(savedPath, equals(path));

      final read = await fileService.readBytes(path);
      expect(read, orderedEquals(data));
    });

    test('deleteFile 删除文件', () async {
      final path = fileService.generateMusicPath();
      await fileService.saveBytes(path, [1, 2, 3]);

      expect(await fileService.fileExists(path), isTrue);

      await fileService.deleteFile(path);
      expect(await fileService.fileExists(path), isFalse);
    });

    test('fileSize 返回正确大小', () async {
      final path = fileService.generateCoverPath();
      final data = List<int>.filled(1024, 0xFF);
      await fileService.saveBytes(path, data);

      final size = await fileService.fileSize(path);
      expect(size, 1024);
    });

    test('generateRecordingPath 生成唯一路径', () async {
      final p1 = fileService.generateRecordingPath();
      // 等待 1ms 确保时间戳不同
      await Future.delayed(const Duration(milliseconds: 2));
      final p2 = fileService.generateRecordingPath();
      expect(p1, isNot(equals(p2)));
    });

    test('generateMusicPath 包含风格种子', () {
      final path = fileService.generateMusicPath(styleSeed: 'jazz');
      expect(path, contains('jazz'));
    });

    test('fileExists 对不存在文件返回 false', () async {
      final path = '${fileService.recordingsDir}/nonexistent.file';
      final exists = await fileService.fileExists(path);
      expect(exists, isFalse);
    });

    test('clearExports 清空导出目录', () async {
      // 先放两个文件进去
      await fileService.saveBytes(
        '${fileService.exportsDir}/temp1.txt', [1],
      );
      await fileService.saveBytes(
        '${fileService.exportsDir}/temp2.txt', [2],
      );

      await fileService.clearExports();

      expect(
        await fileService.fileExists('${fileService.exportsDir}/temp1.txt'),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  4. WorkRepository — 作品 CRUD
  // ─────────────────────────────────────────────────────────────

  group('4. WorkRepository — 作品仓库', () {
    late WorkRepository repo;
    int workCounter = 0;

    setUp(() async {
      repo = WorkRepository();
    });

    MusicWork makeWork({String title = '测试作品', String sourceModule = 'humming_garden'}) {
      workCounter++;
      final now = DateTime.now();
      return MusicWork(
        id: '${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 100000}_$workCounter',
        title: title,
        audioPath: '/test/audio.mp3',
        duration: const Duration(seconds: 30),
        sourceModule: sourceModule,
        styleSeed: StyleSeed.morningDew,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('insert → getById 写入并读取', () async {
      final work = makeWork();
      await repo.insert(work);

      final fetched = await repo.getById(work.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, '测试作品');
      expect(fetched.audioPath, '/test/audio.mp3');
      expect(fetched.duration.inSeconds, 30);
    });

    test('getAll 返回所有作品', () async {
      await repo.insert(makeWork(title: 'A'));
      await repo.insert(makeWork(title: 'B'));
      await repo.insert(makeWork(title: 'C'));

      final all = await repo.getAll();
      expect(all.length, 3);
    });

    test('getByModule 按模块筛选', () async {
      await repo.insert(makeWork(title: 'Garden', sourceModule: 'humming_garden'));
      await repo.insert(makeWork(title: 'Radio', sourceModule: 'mood_radio'));

      final garden = await repo.getByModule('humming_garden');
      expect(garden.length, 1);
      expect(garden.first.title, 'Garden');
    });

    test('getFavorites 只返回收藏作品', () async {
      final w1 = makeWork(title: 'fav');
      final w2 = makeWork(title: 'not_fav');
      await repo.insert(w1.copyWith(isFavorite: true));
      await repo.insert(w2);

      final favs = await repo.getFavorites();
      expect(favs.length, 1);
      expect(favs.first.title, 'fav');
    });

    test('toggleFavorite 切换收藏状态', () async {
      final work = makeWork();
      await repo.insert(work);

      await repo.toggleFavorite(work.id);
      var fetched = await repo.getById(work.id);
      expect(fetched!.isFavorite, isTrue);

      await repo.toggleFavorite(work.id);
      fetched = await repo.getById(work.id);
      expect(fetched!.isFavorite, isFalse);
    });

    test('update 更新作品字段', () async {
      final work = makeWork(title: '原始标题');
      await repo.insert(work);

      await repo.update(work.copyWith(title: '修改后的标题'));
      final fetched = await repo.getById(work.id);
      expect(fetched!.title, '修改后的标题');
    });

    test('search 模糊搜索标题', () async {
      await repo.insert(makeWork(title: '春江花月夜'));
      await repo.insert(makeWork(title: '夏日漱石'));
      await repo.insert(makeWork(title: '秋日私语'));

      final results = await repo.search('花月');
      expect(results.length, 1);
      expect(results.first.title, '春江花月夜');
    });

    test('delete 删除作品', () async {
      final work = makeWork();
      await repo.insert(work);

      await repo.delete(work.id);
      final fetched = await repo.getById(work.id);
      expect(fetched, isNull);
    });

    test('deleteAll 批量删除', () async {
      final w1 = makeWork(title: 'A');
      final w2 = makeWork(title: 'B');
      await repo.insert(w1);
      await repo.insert(w2);

      await repo.deleteAll([w1.id, w2.id]);
      final all = await repo.getAll();
      expect(all, isEmpty);
    });

    test('count 返回正确数量', () async {
      for (var i = 0; i < 5; i++) {
        await repo.insert(makeWork(title: 'W$i'));
      }
      final c = await repo.count();
      expect(c, 5);
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  5. SoundRepository — 声音样本 CRUD (验证蛇形命名修复)
  // ─────────────────────────────────────────────────────────────

  group('5. SoundRepository — 声音样本仓库 (蛇形命名验证)', () {
    late SoundRepository repo;

    setUp(() async {
      repo = SoundRepository();
    });

    SoundSample makeSample({String name = '测试声音'}) {
      return SoundSample.create(
        name: name,
        audioPath: '/samples/test.wav',
        type: SoundType.nature,
        bpm: 120.0,
        pitchSequence: 'C-D-E',
        timbreFeature: 'bright',
      );
    }

    test('insert → getAll 写入并正确读取 (验证蛇形命名)', () async {
      final sample = makeSample(name: '鸟鸣声');
      await repo.insert(sample);

      final all = await repo.getAll();
      expect(all.length, 1);

      final fetched = all.first;
      expect(fetched.name, '鸟鸣声');
      expect(fetched.type, SoundType.nature);
      expect(fetched.bpm, 120.0);
      expect(fetched.pitchSequence, 'C-D-E');
      expect(fetched.timbreFeature, 'bright');
    });

    test('getById 按 ID 查询', () async {
      final sample = makeSample(name: '流水声');
      await repo.insert(sample);

      final fetched = await repo.getById(sample.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, '流水声');
    });

    test('update 更新样本', () async {
      final sample = makeSample(name: '原始');
      await repo.insert(sample);

      await repo.update(SoundSample(
        id: sample.id,
        name: '更新后',
        audioPath: sample.audioPath,
        type: SoundType.mechanical,
        createdAt: sample.createdAt,
      ),);

      final fetched = await repo.getById(sample.id);
      expect(fetched!.name, '更新后');
      expect(fetched.type, SoundType.mechanical);
    });

    test('delete 删除样本', () async {
      final sample = makeSample();
      await repo.insert(sample);

      await repo.delete(sample.id);
      final fetched = await repo.getById(sample.id);
      expect(fetched, isNull);
    });

    test('count 返回正确数量', () async {
      await repo.insert(makeSample(name: 'S1'));
      await repo.insert(makeSample(name: 'S2'));

      expect(await repo.count(), 2);
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  6. VoiceCardRepository — 明信片 CRUD + 新方法
  // ─────────────────────────────────────────────────────────────

  group('6. VoiceCardRepository — 明信片仓库', () {
    late VoiceCardRepository repo;
    int cardCounter = 0;

    setUp(() async {
      repo = VoiceCardRepository();
    });

    VoiceCard makeCard({
      String workId = 'work_001',
    }) {
      cardCounter++;
      return VoiceCard(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}_$cardCounter',
        workId: workId,
        senderId: 'sender_001',
        recipientId: 'recipient_001',
        audioPath: '/cards/test.m4a',
        textContent: '这是一张明信片',
        createdAt: DateTime.now(),
      );
    }

    test('insert → getAll 写入并读取', () async {
      await repo.insert(makeCard(workId: 'w1'));
      await repo.insert(makeCard(workId: 'w2'));

      final all = await repo.getAll();
      expect(all.length, 2);
    });

    test('getById 按 ID 查询', () async {
      final card = makeCard(workId: 'w_target');
      await repo.insert(card);

      final fetched = await repo.getById(card.id);
      expect(fetched, isNotNull);
      expect(fetched!.workId, 'w_target');
    });

    test('getByWorkId 按作品 ID 查询 (新方法)', () async {
      await repo.insert(makeCard(workId: 'song_A'));
      await repo.insert(makeCard(workId: 'song_A'));
      await repo.insert(makeCard(workId: 'song_B'));

      final cards = await repo.getByWorkId('song_A');
      expect(cards.length, 2);
    });

    test('delete 删除明信片', () async {
      final card = makeCard();
      await repo.insert(card);

      await repo.delete(card.id);
      final all = await repo.getAll();
      expect(all, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  7. UserProfileRepository — 档案 CRUD + delete
  // ─────────────────────────────────────────────────────────────

  group('7. UserProfileRepository — 用户档案仓库', () {
    late UserProfileRepository repo;

    setUp(() async {
      repo = UserProfileRepository();
    });

    UserProfile makeProfile({String nickname = '小明'}) {
      return UserProfile(
        localId: 'local_001',
        nickname: nickname,
        voiceBaselinePath: '/profiles/baseline.wav',
        guardianAnimal: GuardianAnimal.panda,
        role: UserRole.student,
        hasCompletedOnboarding: false,
        createdAt: DateTime.now(),
      );
    }

    test('save → get 写入并读取', () async {
      await repo.save(makeProfile(nickname: '小红'));

      final profile = await repo.get();
      expect(profile, isNotNull);
      expect(profile!.nickname, '小红');
      expect(profile.guardianAnimal, GuardianAnimal.panda);
      expect(profile.role, UserRole.student);
      expect(profile.hasCompletedOnboarding, isFalse);
    });

    test('save 更新已有档案', () async {
      await repo.save(makeProfile(nickname: '原始昵称'));

      await repo.save(makeProfile(nickname: '新昵称'));

      final profile = await repo.get();
      expect(profile!.nickname, '新昵称');
    });

    test('setOnboardingCompleted 更新引导状态', () async {
      await repo.save(makeProfile());

      await repo.setOnboardingCompleted(true);

      final profile = await repo.get();
      expect(profile!.hasCompletedOnboarding, isTrue);
    });

    test('delete 删除档案 (新方法)', () async {
      await repo.save(makeProfile());

      await repo.delete();

      final profile = await repo.get();
      expect(profile, isNull);
    });

    test('get 对空表返回 null', () async {
      final profile = await repo.get();
      expect(profile, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────
  //  8. 集成测试 — 多表联合操作
  // ─────────────────────────────────────────────────────────────

  group('8. 集成测试 — 多表联合操作', () {
    test('作品 + 加密 + 明信片全流程', () async {
      // Step 1: 加密标题
      const rawTitle = '我的第一首歌';
      await EncryptionService().initialize('integration_test');
      final encryptedTitle = EncryptionService().encryptText(rawTitle);

      // Step 2: 保存作品
      final work = MusicWork(
        id: 'integ_work_1',
        title: encryptedTitle,
        audioPath: '/files/song.mp3',
        styleSeed: StyleSeed.morningDew,
        duration: const Duration(seconds: 45),
        sourceModule: 'humming_garden',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await WorkRepository().insert(work);

      // Step 3: 关联明信片
      final card = VoiceCard(
        id: 'integ_card_1',
        workId: work.id,
        senderId: 'user_1',
        textContent: '分享给你！',
        createdAt: DateTime.now(),
      );
      await VoiceCardRepository().insert(card);

      // Step 4: 验证
      final fetchedWork = await WorkRepository().getById(work.id);
      expect(fetchedWork, isNotNull);
      expect(
        EncryptionService().decryptText(fetchedWork!.title),
        rawTitle,
      );

      final cards = await VoiceCardRepository().getByWorkId(work.id);
      expect(cards.length, 1);
      expect(cards.first.textContent, '分享给你！');
    });
  });
}
