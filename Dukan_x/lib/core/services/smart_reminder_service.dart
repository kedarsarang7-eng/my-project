import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/bill.dart';
import '../../models/customer.dart';

enum ReminderTone { friendly, firm, finalWarning }

class SmartReminderService {
  /// Generates a context-aware reminder message
  String getReminderMessage({
    required Bill bill,
    required Customer customer,
    String? shopName,
    ReminderTone? overrideTone,
  }) {
    final daysOverdue = _getDaysOverdue(bill);
    final tone = overrideTone ?? _determineTone(daysOverdue);
    final festivalGreeting = _getFestivalGreeting();

    final customerName = customer.name.isNotEmpty ? customer.name : 'Customer';
    final businessName = shopName ?? 'our store';
    final amount = '₹${bill.grandTotal.toStringAsFixed(0)}';
    // Compute due date as bill date + 7 days (default grace period)
    final computedDueDate = bill.date.add(const Duration(days: 7));
    final dueDate = DateFormat('dd MMM').format(computedDueDate);

    final sb = StringBuffer();

    // 1. Festival Greeting (if any)
    if (festivalGreeting != null) {
      sb.write('$festivalGreeting ');
    }

    // 2. Core Message based on Tone
    switch (tone) {
      case ReminderTone.friendly:
        sb.write(
          'Hello $customerName, just a gentle reminder that your bill of $amount is pending. ',
        );
        sb.write(
          'Please pay by $dueDate to avoid any hassle. Thank you for shopping with $businessName!',
        );
        break;

      case ReminderTone.firm:
        sb.write(
          'Dear $customerName, your payment of $amount is overdue by $daysOverdue days. ',
        );
        sb.write(
          'Please clear this amount immediately to maintain a good credit limit with $businessName.',
        );
        break;

      case ReminderTone.finalWarning:
        sb.write(
          'URGENT: $customerName, your bill of $amount is severely overdue ($daysOverdue days). ',
        );
        sb.write(
          'Please pay immediately. Failure to do so may affect future credit services.',
        );
        break;
    }

    return sb.toString();
  }

  /// Launches WhatsApp with the pre-filled message
  Future<void> launchWhatsApp(String phone, String message) async {
    // Clean phone number (remove +91, spaces, etc. if needed, but usually +91 is good)
    var cleanPhone = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.length == 10) {
        cleanPhone = '+91$cleanPhone'; // Default to India if 10 digits
      }
    }

    // Use specific WhatsApp URL scheme
    final url = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );

    // Fallback to web link if app not installed (or generic launch)
    final webUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback/log
      throw Exception('Could not launch WhatsApp');
    }
  }

  /// Launches SMS app
  Future<void> launchSMS(String phone, String message) async {
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{'body': message},
    );
    if (await canLaunchUrl(smsLaunchUri)) {
      await launchUrl(smsLaunchUri);
    } else {
      throw Exception('Could not launch SMS');
    }
  }

  // --- Helpers ---

  int _getDaysOverdue(Bill bill) {
    // Compute due date as bill date + 7 days (default grace period)
    final dueDate = bill.date.add(const Duration(days: 7));
    final diff = DateTime.now().difference(dueDate);
    return diff.inDays > 0 ? diff.inDays : 0;
  }

  ReminderTone _determineTone(int daysOverdue) {
    if (daysOverdue > 30) return ReminderTone.finalWarning;
    if (daysOverdue > 7) return ReminderTone.firm;
    return ReminderTone.friendly;
  }

  String? _getFestivalGreeting() {
    final now = DateTime.now();
    // Simplified fixed dates for demo. In production, use a library or dynamic config.
    // Format: MM-DD
    final currentKey = '${now.month}-${now.day}';

    // 2024-2025 Major Festival Map (Approximate)
    const festivals = {
      '10-31': 'Happy Diwali!', // 2024
      '11-01': 'Happy Diwali!',
      '12-25': 'Merry Christmas!',
      '1-1': 'Happy New Year!',
      '3-14': 'Happy Holi!', // 2025
      '3-31': 'Eid Mubarak!', // 2025 (Approx)
    };

    return festivals[currentKey];
  }
}
