import 'package:intl/intl.dart';

class DateFormatter {
  const DateFormatter._();

  /// Converts UTC/ISO timestamp to IST display format.
  static String toIstDateTime(String utcIso) {
    final utc = DateTime.parse(utcIso).toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
  }

  static String toIstDate(String utcIso) {
    final utc = DateTime.parse(utcIso).toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy').format(ist);
  }
}
