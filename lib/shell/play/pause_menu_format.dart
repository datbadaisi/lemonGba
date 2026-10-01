/// Pure date/relative helpers for pause-menu slot labels.
abstract final class PauseMenuFormat {
  static String slotSavedAt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  static String relativeAgo(DateTime dt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(dt);
    if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return m == 1 ? '1 minute ago' : '$m minutes ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    }
    if (diff.inDays < 30) {
      final d = diff.inDays;
      return d == 1 ? '1 day ago' : '$d days ago';
    }
    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor().clamp(1, 11);
      return mo == 1 ? '1 month ago' : '$mo months ago';
    }
    final y = (diff.inDays / 365).floor().clamp(1, 99);
    return y == 1 ? '1 year ago' : '$y years ago';
  }
}
