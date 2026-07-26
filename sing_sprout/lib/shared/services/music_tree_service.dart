import '../models/music_tree_data.dart';
import '../models/mood_record.dart';
import '../repositories/work_repository.dart';
import 'local_storage_service.dart';

/// 音乐树数据聚合服务 — 极简 MVP 版
///
/// 从 WorkRepository 读取作品数据 + 本地心情历史，
/// 计算「技能+心情」双维度成长状态。
///
/// 按优化方案，MVP 聚焦作品数量 + 连续活跃两维度，
/// 补充心情维度连接，避免 7 项指标过度工程化。
class MusicTreeService {
  MusicTreeService._();

  static const _moodHistoryFile = 'mood_history.json';

  /// 聚合计算 MusicTreeData（含心情维度）
  static Future<MusicTreeData> calculate() async {
    final repo = WorkRepository();
    final works = await repo.getAll();
    final moods = await _readMoodHistory();

    final now = DateTime.now();

    // ── 无数据：返回萌芽状态 ──
    if (works.isEmpty && moods.isEmpty) {
      return MusicTreeData(lastActiveDate: now);
    }

    final sortedWorks = List.of(works)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // ── 技能维度 — 作品数量 ──
    final totalWorks = sortedWorks.length;

    // ── 活跃维度 — 累计/连续使用天数 ──
    final activeDays = <String>{};
    for (final w in sortedWorks) {
      activeDays.add(_dateKey(w.createdAt));
    }
    final totalDays = activeDays.length;
    final lastActiveDate = works.isEmpty
        ? (moods.isNotEmpty ? moods.first.date : now)
        : sortedWorks.first.createdAt;

    // 连续使用天数：从昨天开始往前数（今天可能还没创作）
    int streakDays = 0;
    for (int i = 1; i < 365; i++) {
      final check = now.subtract(Duration(days: i));
      if (activeDays.contains(_dateKey(check))) {
        streakDays++;
      } else {
        break;
      }
    }

    // ── 心情维度 ──
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentMoods = moods
        .where((m) => m.date.isAfter(thirtyDaysAgo))
        .toList();

    final moodRecordCount = moods.length;
    final positiveMoodDays = recentMoods
        .where((m) => !m.isNegative)
        .map((m) => _dateKey(m.date))
        .toSet()
        .length;
    final negativeMoodDays = recentMoods
        .where((m) => m.isNegative)
        .map((m) => _dateKey(m.date))
        .toSet()
        .length;

    // ── 连接统计（估算） ──
    final sharedCards = sortedWorks
        .where((w) => w.note != null && w.note!.isNotEmpty)
        .length;
    final receivedReplies = _estimateReplies(works, moods);

    // ── 综合成长能量 0-100 ──
    // 作品贡献：每首作品最多 15 分，≥7 首封顶
    // 连续活跃贡献：每天 5 分，≥14 天封顶
    // 心情表达贡献：每次记录 3 分，≥10 次封顶
    // 积极心情加成：每天 2 分
    final workEnergy = (totalWorks * 15).clamp(0, 55).toDouble();
    final streakEnergy = (streakDays * 5).clamp(0, 25).toDouble();
    final moodEnergy = (moodRecordCount * 3).clamp(0, 15).toDouble();
    final positiveBonus = (positiveMoodDays * 2).clamp(0, 10).toDouble();
    final growthEnergy = (workEnergy + streakEnergy + moodEnergy + positiveBonus)
        .clamp(0, 100)
        .toDouble();

    final data = MusicTreeData(
      totalWorks: totalWorks,
      streakDays: streakDays,
      moodRecordCount: moodRecordCount,
      positiveMoodDays: positiveMoodDays,
      negativeMoodDays: negativeMoodDays,
      lastActiveDate: lastActiveDate,
      totalDays: totalDays,
      sharedCards: sharedCards,
      receivedReplies: receivedReplies,
      growthEnergy: growthEnergy,
    );

    return data.copyWith(
      treeState: MusicTreeData.calculateState(data),
    );
  }

  /// 估算收到的回信数（从作品 note 和心情数据推断）
  static int _estimateReplies(List<dynamic> works, List<MoodRecord> moods) {
    // MVP 阶段：VoiceCard 模型尚未持久化，无法准确统计
    // 使用发送明信片数量 * 0.3 作为粗略估算（假设约 30% 回复率）
    final shared = works
        .where((w) => w.note != null && (w.note as String).isNotEmpty)
        .length;
    return (shared * 0.3).round();
  }

  /// 从本地存储读取心情历史
  static Future<List<MoodRecord>> _readMoodHistory() async {
    final storage = LocalStorageService();
    final raw = await storage.readList(_moodHistoryFile);
    return raw.map((m) => MoodRecord.fromJson(m)).toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
