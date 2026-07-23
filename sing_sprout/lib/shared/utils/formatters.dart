/// 共享的格式化工具函数
class Formatters {
  Formatters._();

  /// 格式化日期为 "YYYY-MM-DD"。
  static String formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  /// 格式化日期为 "YYYY年M月D日"。
  static String formatDateChinese(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 格式化为短日期（如 "1月12日"）。
  static String formatDateShort(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  /// 格式化时长为 "XhYm" 或 "Xm" 格式。
  static String formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  /// 格式化时长为 "M:SS" 格式。
  static String formatDurationMinSec(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化时长为 "H:MM:SS" 格式。
  static String formatDurationFull(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
