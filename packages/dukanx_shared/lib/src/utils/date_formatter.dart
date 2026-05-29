import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _date = DateFormat('dd MMM yyyy', 'en_IN');
  static final _dateShort = DateFormat('dd MMM', 'en_IN');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a', 'en_IN');
  static final _monthYear = DateFormat('MMM yyyy', 'en_IN');

  static String format(DateTime dt) => _date.format(dt);
  static String formatShort(DateTime dt) => _dateShort.format(dt);
  static String formatDateTime(DateTime dt) => _dateTime.format(dt);
  static String formatMonthYear(DateTime dt) => _monthYear.format(dt);

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return format(dt);
  }
}
