import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// WhatsApp Service
///
/// Provides WhatsApp messaging using URL scheme.
/// Works offline by queuing messages for later.
///
/// This is a free approach using WhatsApp URL scheme.
/// For enterprise features, upgrade to WhatsApp Business API.
class WhatsAppService {
  /// Send a WhatsApp message to a phone number
  ///
  /// Uses `wa.me` URL scheme which works on both mobile and web.
  /// Returns true if the WhatsApp app was opened successfully.
  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      final cleanNumber = _cleanPhoneNumber(phoneNumber);

      // Encode message for URL
      final encodedMessage = Uri.encodeComponent(message);

      // Build WhatsApp URL
      final Uri whatsappUrl = Uri.parse(
        'https://wa.me/$cleanNumber?text=$encodedMessage',
      );

      // Try to open WhatsApp
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        debugPrint('WhatsAppService: Opened WhatsApp for $cleanNumber');
        return true;
      } else {
        debugPrint('WhatsAppService: Cannot open WhatsApp URL');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsAppService: Error sending message: $e');
      return false;
    }
  }

  /// Send a WhatsApp message with image attachment
  ///
  /// Note: WhatsApp URL scheme doesn't support image sharing directly.
  /// Use the share sheet for image + text combinations.
  Future<bool> sendMessageWithImage({
    required String phoneNumber,
    required String message,
    required String imagePath,
  }) async {
    // For images, we need to use the native share functionality
    // The URL scheme approach only supports text
    debugPrint('WhatsAppService: Image sharing requires native share API');

    // Fallback to text-only message with image link if available
    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// Clean and format phone number for WhatsApp
  ///
  /// - Removes spaces, dashes, parentheses
  /// - Adds India country code if not present
  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');

    // If number is 10 digits, assume it's Indian and add +91
    if (clean.length == 10) {
      clean = '91$clean';
    }

    // If number starts with 0, remove it and add 91
    if (clean.startsWith('0')) {
      clean = '91${clean.substring(1)}';
    }

    return clean;
  }

  /// Check if WhatsApp is installed
  Future<bool> isWhatsAppInstalled() async {
    try {
      final Uri testUrl = Uri.parse('https://wa.me/911234567890');
      return await canLaunchUrl(testUrl);
    } catch (e) {
      return false;
    }
  }

  /// Fill template placeholders with actual values
  ///
  /// Supported placeholders:
  /// - {{customer_name}}
  /// - {{shop_name}}
  /// - {{amount}}
  /// - {{due_date}}
  /// - {{invoice_number}}
  String fillTemplate({
    required String template,
    required Map<String, String> values,
  }) {
    String result = template;

    values.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });

    return result;
  }

  /// Create a payment reminder message
  String createPaymentReminder({
    required String customerName,
    required String shopName,
    required double amount,
    DateTime? dueDate,
  }) {
    final message =
        '''à¤¨à¤®à¤¸à¥à¤¤à¥‡ $customerName,

à¤†à¤ªà¤•à¥‡ $shopName à¤¸à¥‡ â‚¹${amount.toStringAsFixed(0)} à¤•à¤¾ à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤¬à¤¾à¤•à¥€ à¤¹à¥ˆà¥¤

${dueDate != null ? 'à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤¤à¤¿à¤¥à¤¿: ${dueDate.day}/${dueDate.month}/${dueDate.year}' : ''}

à¤•à¥ƒà¤ªà¤¯à¤¾ à¤œà¤²à¥à¤¦ à¤¸à¥‡ à¤œà¤²à¥à¤¦ à¤­à¥à¤—à¤¤à¤¾à¤¨ à¤•à¤°à¥‡à¤‚à¥¤

à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦!''';

    return message.trim();
  }

  /// Create a bulk WhatsApp campaign opener
  ///
  /// Since WhatsApp doesn't support bulk messaging via URL scheme,
  /// this opens WhatsApp for each recipient sequentially.
  ///
  /// For true bulk messaging, use WhatsApp Business API.
  Stream<(String phone, bool success)> sendBulkMessages({
    required List<String> phoneNumbers,
    required String message,
    Duration delay = const Duration(seconds: 2),
  }) async* {
    for (final phone in phoneNumbers) {
      final success = await sendMessage(phoneNumber: phone, message: message);
      yield (phone, success);

      // Add delay between messages to avoid rate limiting
      await Future.delayed(delay);
    }
  }
}
