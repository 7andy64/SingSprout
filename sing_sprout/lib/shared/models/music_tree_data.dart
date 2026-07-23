import '../../core/constants/enums.dart';

/// 音乐树成长数据 — 极简版成长可视化系统
///
/// 按优化方案，MVP 聚焦「作品数量 + 连续活跃」两维度，
/// 补充心情维度连接形成「技能+心情」双维成长树。
/// 其他指标（连接统计、音乐根系）在 P2 阶段恢复。
class MusicTreeData {
  // ── 核心维度（极简 MVP） ──
  final int totalWorks;          // 作品总数 — 技能成长
  final int streakDays;          // 连续使用天数 — 活跃度

  // ── 心情维度 ──
  final int moodRecordCount;     // 心情记录总数
  final int positiveMoodDays;    // 积极心情天数（红色/黄色/绿色，最近 30 天）
  final int negativeMoodDays;    // 消极心情天数（蓝色/紫色，最近 30 天）

  // ── 树状态 ──
  final TreeState treeState;
  final DateTime lastActiveDate;

  // ── 辅助字段（不在 UI 突出展示） ──
  final int totalDays;           // 累计使用天数
  final int sharedCards;         // 发送明信片数（估算）
  final int receivedReplies;     // 收到回信数
  final double growthEnergy;     // 综合成长能量 0-100（作品+心情加权）

  const MusicTreeData({
    this.totalWorks = 0,
    this.streakDays = 0,
    this.moodRecordCount = 0,
    this.positiveMoodDays = 0,
    this.negativeMoodDays = 0,
    this.treeState = TreeState.sprouting,
    required this.lastActiveDate,
    this.totalDays = 0,
    this.sharedCards = 0,
    this.receivedReplies = 0,
    this.growthEnergy = 0,
  });

  /// 根据数据计算树状态（技能 + 心情双维度）
  ///
  /// 技能维度：作品数量
  /// 心情维度：心情记录数 + 积极/消极比例
  /// 活跃维度：连续天数 + 距上次活跃时间
  static TreeState calculateState(MusicTreeData data) {
    final daysSinceLastActive =
        DateTime.now().difference(data.lastActiveDate).inDays;

    // 没有任何活动
    if (data.totalWorks == 0 && data.moodRecordCount == 0) {
      return TreeState.sprouting;
    }

    // 超过 7 天未活跃 → 落叶
    if (daysSinceLastActive > 7) return TreeState.quiet;

    // 作品 ≥ 5 且积极心情 ≥ 3 天 → 盛开
    if (data.totalWorks >= 5 && data.positiveMoodDays >= 3) {
      return TreeState.blooming;
    }

    // 有作品但很少心情表达 → 沉思
    if (data.totalWorks >= 3 && data.moodRecordCount < 2) {
      return TreeState.thinking;
    }

    // 有心情表达但作品少 → 成长中
    if (data.moodRecordCount >= 3 && data.totalWorks < 5) {
      return TreeState.growing;
    }

    // 两者都有一定积累 → 成长中
    if (data.totalWorks >= 1) {
      return TreeState.growing;
    }

    // 仅有心情记录 → 萌芽（刚开始）
    return TreeState.sprouting;
  }

  MusicTreeData copyWith({
    int? totalWorks,
    int? streakDays,
    int? moodRecordCount,
    int? positiveMoodDays,
    int? negativeMoodDays,
    TreeState? treeState,
    DateTime? lastActiveDate,
    int? totalDays,
    int? sharedCards,
    int? receivedReplies,
    double? growthEnergy,
  }) {
    return MusicTreeData(
      totalWorks: totalWorks ?? this.totalWorks,
      streakDays: streakDays ?? this.streakDays,
      moodRecordCount: moodRecordCount ?? this.moodRecordCount,
      positiveMoodDays: positiveMoodDays ?? this.positiveMoodDays,
      negativeMoodDays: negativeMoodDays ?? this.negativeMoodDays,
      treeState: treeState ?? this.treeState,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      totalDays: totalDays ?? this.totalDays,
      sharedCards: sharedCards ?? this.sharedCards,
      receivedReplies: receivedReplies ?? this.receivedReplies,
      growthEnergy: growthEnergy ?? this.growthEnergy,
    );
  }
}
