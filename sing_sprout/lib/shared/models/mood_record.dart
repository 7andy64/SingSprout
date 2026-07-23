import '../../core/constants/enums.dart';

/// 每日心情记录 — 本地持久化
class MoodRecord {
  final DateTime date;
  final MoodColor mood;

  const MoodRecord({
    required this.date,
    required this.mood,
  });

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

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mood': mood.name,
      };

  factory MoodRecord.fromJson(Map<String, dynamic> json) => MoodRecord(
        date: DateTime.parse(json['date'] as String),
        mood: MoodColor.values.byName(json['mood'] as String),
      );
}
