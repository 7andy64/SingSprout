import '../models/music_tree_data.dart';
import 'work_repository.dart';

/// 音乐树数据聚合服务
///
/// 从 WorkRepository 读取全部作品，自动计算
/// 创作统计、成长状态和基础乐感评分。
class MusicTreeService {
  MusicTreeService._();

  /// 聚合计算 MusicTreeData
  static Future<MusicTreeData> calculate() async {
    final repo = WorkRepository();
    final works = await repo.getWorks();

    if (works.isEmpty) {
      return MusicTreeData(lastActiveDate: DateTime.now());
    }

    final now = DateTime.now();
    final sorted = List.of(works)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 作品总数
    final totalWorks = sorted.length;

    // 累计使用天数（按作品创建日期去重）
    final activeDays = <String>{};
    for (final w in sorted) {
      activeDays.add(_dateKey(w.createdAt));
    }
    final totalDays = activeDays.length;
    final lastActiveDate = sorted.first.createdAt;

    // 连续使用天数（从今天往前数）
    int streakDays = 0;
    for (int i = 0; i < 365; i++) {
      final check = now.subtract(Duration(days: i));
      if (activeDays.contains(_dateKey(check))) {
        streakDays++;
      } else if (i > 0) {
        break;
      }
      // i==0 (今天) 如果没有记录，继续往前看
    }

    // 发送/回信统计（从作品 note 中简单推断 — 有 note 的作品视为分享过）
    final sharedCards = sorted.where((w) => w.note != null && w.note!.isNotEmpty).length;
    final receivedReplies = 0; // 回复数据在 VoiceCard 模型中，暂不跨模型聚合

    // 基础乐感评分（简化版：基于作品数量和质量推断）
    final rhythmScore = _clampScore(totalWorks * 10.0);
    final pitchScore = _clampScore(totalWorks * 12.0 + (sharedCards > 0 ? 10 : 0));
    final listeningScore = _clampScore(totalDays * 5.0);

    final data = MusicTreeData(
      totalWorks: totalWorks,
      totalDays: totalDays,
      streakDays: streakDays,
      sharedCards: sharedCards,
      receivedReplies: receivedReplies,
      rhythmScore: rhythmScore,
      pitchScore: pitchScore,
      listeningScore: listeningScore,
      lastActiveDate: lastActiveDate,
    );

    return data.copyWith(
      treeState: MusicTreeData.calculateState(data),
    );
  }

  static double _clampScore(double v) => v.clamp(0, 100);

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
