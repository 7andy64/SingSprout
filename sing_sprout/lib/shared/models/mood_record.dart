import '../../core/constants/enums.dart';

/// 心情表达入口类型
enum MoodEntryType {
  color,   // 颜色选择
  humming, // 自由哼唱
  text,    // 文字表达
}

/// 心情记录去向
enum MoodDestination {
  private, // 仅自己可见（私密空间）
  send,    // 寄给爸妈
  teacher, // 给老师看
  discard, // 不保存
}

/// 每日心情记录 — 本地持久化
class MoodRecord {
  final DateTime date;
  final MoodColor mood;
  final MoodEntryType entryType;
  final String? note;
  final MoodDestination? destination;

  const MoodRecord({
    required this.date,
    required this.mood,
    this.entryType = MoodEntryType.color,
    this.note,
    this.destination,
  });

  /// 是否为负面心情（想念/不开心）
  bool get isNegative =>
      mood == MoodColor.blue || mood == MoodColor.purple;

  /// 按日期聚合（同一天多次选择以最后一次为准）
  static List<MoodRecord> dedupeByDate(List<MoodRecord> records) {
    final map = <String, MoodRecord>{};
    for (final r in records) {
      final key = _dateKey(r.date);
      map[key] = r;
    }
    final sorted = map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  /// 检查是否连续 N 天均为负面心情（用于安全护栏）
  static bool hasConsecutiveNegatives(List<MoodRecord> records, int days) {
    if (records.length < days) return false;
    final sorted = dedupeByDate(records);
    for (int i = 0; i < days && i < sorted.length; i++) {
      if (!sorted[i].isNegative) return false;
    }
    return true;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mood': mood.name,
        'entryType': entryType.name,
        if (note != null) 'note': note,
        if (destination != null) 'destination': destination!.name,
      };

  factory MoodRecord.fromJson(Map<String, dynamic> json) => MoodRecord(
        date: DateTime.parse(json['date'] as String),
        mood: MoodColor.values.byName(json['mood'] as String),
        entryType: json['entryType'] != null
            ? MoodEntryType.values.byName(json['entryType'] as String)
            : MoodEntryType.color,
        note: json['note'] as String?,
        destination: json['destination'] != null
            ? MoodDestination.values.byName(json['destination'] as String)
            : null,
      );
}
