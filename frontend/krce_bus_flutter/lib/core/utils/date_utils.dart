class AppDateUtils {
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Parses any ISO timestamp string or time string into Indian Standard Time (IST, UTC+5:30)
  static DateTime parseToIst(String raw) {
    if (raw.isEmpty) return DateTime.now();
    try {
      // Handles short time strings like "11:11" or "11:11:00"
      if (raw.length <= 8 && raw.contains(':')) {
        final parts = raw.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, h, m);
      }

      final dt = DateTime.parse(raw);

      // Dart's DateTime.parse() converts ISO strings with timezone offsets (e.g. "+05:30" or "Z")
      // into UTC moments internally (e.g. "11:11:18+05:30" becomes 05:41:18 UTC).
      // Converting to UTC and adding 5 hours 30 minutes guarantees exact IST wall-clock time (11:11 AM).
      if (raw.contains('Z') || raw.contains('z') || raw.contains('+') || (raw.split('-').length > 3)) {
        return dt.toUtc().add(const Duration(hours: 5, minutes: 30));
      }

      // Naive ISO string without offset (e.g. "2026-07-28T11:11:18")
      return dt;
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Formats time in IST (e.g. "11:11 AM")
  static String formatTimeIst(String raw) {
    if (raw.isEmpty) return '--';
    try {
      final dt = parseToIst(raw);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    } catch (_) {
      return raw;
    }
  }

  /// Formats date in IST (e.g. "28 Jul 2026")
  static String formatDateIst(String raw) {
    if (raw.isEmpty) return '--';
    try {
      final dt = parseToIst(raw);
      return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  /// Formats full datetime in IST (e.g. "28 Jul 2026 • 11:11 AM IST")
  static String formatDateTimeIst(String raw) {
    if (raw.isEmpty) return '--';
    try {
      final dt = parseToIst(raw);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}  •  $hour:$min $ampm IST';
    } catch (_) {
      return raw;
    }
  }
}
