import '../../core/constants/enums.dart';

/// 音乐树成长数据 — 成长可视化系统核心
class MusicTreeData {
  final int totalWorks;          // 作品总数
  final int totalDays;           // 累计使用天数
  final int streakDays;          // 连续使用天数
  final int sharedCards;         // 发送明信片数
  final int receivedReplies;     // 收到回信数
  final double rhythmScore;      // 节奏感评分 0-100
  final double pitchScore;       // 音准评分 0-100
  final double listeningScore;   // 听辨评分 0-100
  final TreeState treeState;
  final DateTime lastActiveDate;

  const MusicTreeData({
    this.totalWorks = 0,
    this.totalDays = 0,
    this.streakDays = 0,
    this.sharedCards = 0,
    this.receivedReplies = 0,
    this.rhythmScore = 0,
    this.pitchScore = 0,
    this.listeningScore = 0,
    this.treeState = TreeState.sprouting,
    required this.lastActiveDate,
  });

  /// 根据数据计算树状态
  static TreeState calculateState(MusicTreeData data) {
    final daysSinceLastActive =
        DateTime.now().difference(data.lastActiveDate).inDays;

    if (data.totalWorks == 0) return TreeState.sprouting;
    if (daysSinceLastActive > 7) return TreeState.quiet;
    if (data.totalWorks >= 5 && data.sharedCards >= 3) {
      return TreeState.blooming;
    }
    if (data.sharedCards == 0 && data.totalWorks >= 3) {
      return TreeState.thinking;
    }
    return TreeState.growing;
  }

  MusicTreeData copyWith({
    int? totalWorks,
    int? totalDays,
    int? streakDays,
    int? sharedCards,
    int? receivedReplies,
    double? rhythmScore,
    double? pitchScore,
    double? listeningScore,
    TreeState? treeState,
    DateTime? lastActiveDate,
  }) {
    return MusicTreeData(
      totalWorks: totalWorks ?? this.totalWorks,
      totalDays: totalDays ?? this.totalDays,
      streakDays: streakDays ?? this.streakDays,
      sharedCards: sharedCards ?? this.sharedCards,
      receivedReplies: receivedReplies ?? this.receivedReplies,
      rhythmScore: rhythmScore ?? this.rhythmScore,
      pitchScore: pitchScore ?? this.pitchScore,
      listeningScore: listeningScore ?? this.listeningScore,
      treeState: treeState ?? this.treeState,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }
}
