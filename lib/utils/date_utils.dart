import 'package:intl/intl.dart';

class DateFormatting {
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days from [from] to [to], ignoring time of day and DST.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// ISO-8601 in UTC without fractional seconds, e.g. 2026-10-25T14:00:00Z.
  /// This is exactly what Swift's JSONEncoder `.iso8601` strategy reads and
  /// writes, so backups move freely between this app and the native iOS app.
  static String toIso(DateTime d) {
    final u = d.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static DateTime? parseIso(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static String abbreviated(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String long(DateTime d) => DateFormat('d MMMM yyyy').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String dateTimeShort(DateTime d) => DateFormat('d MMM yyyy, HH:mm').format(d);
}
