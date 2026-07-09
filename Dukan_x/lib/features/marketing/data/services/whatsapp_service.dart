import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/openwa/openwa_client.dart';
import '../../../../core/openwa/openwa_tenant_service.dart';

/// WhatsApp Marketing Service
///
/// Handles WhatsApp messaging for marketing campaigns.
///
/// **Primary path**: OpenWA API gateway for native delivery with bulk support.
/// **Fallback path**: wa.me URL scheme for single-message local delivery.
///
/// Migration note: This service previously relied exclusively on wa.me URL
/// schemes. It now routes through OpenWA for reliable, trackable delivery
/// including batch progress monitoring via the send-bulk endpoint.
class WhatsAppService {
  OpenWATenantService? _tenantService;

  /// Lazy-initialize tenant service (may not be available in all contexts).
  OpenWATenantService? get _tenant {
    _tenantService ??= _resolveTenantService();
    return _tenantService;
  }

  /// Send a WhatsApp message to a phone number.
  ///
  /// Tries OpenWA API first, then falls back to wa.me URL scheme.
  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    // 1. Try OpenWA API (preferred — native delivery, delivery tracking)
    final sent = await _sendViaOpenWA(phoneNumber, message);
    if (sent) return true;

    // 2. Fallback to wa.me URL scheme
    return _sendViaUrlScheme(phoneNumber, message);
  }

  /// Send a WhatsApp message with image attachment.
  ///
  /// Uses OpenWA's send-image endpoint. Falls back to text-only via URL scheme.
  Future<bool> sendMessageWithImage({
    required String phoneNumber,
    required String message,
    required String imagePath,
  }) async {
    try {
      final tenant = _tenant;
      if (tenant == null) {
        return sendMessage(phoneNumber: phoneNumber, message: message);
      }

      final connected = await tenant.isConnected();
      if (!connected) {
        return sendMessage(phoneNumber: phoneNumber, message: message);
      }

      final config = await tenant.getBusinessConfig();
      final client = await tenant.getClient();
      final chatId = _formatChatId(phoneNumber);

      // If it's a URL, send via url parameter; otherwise it was a local path
      if (imagePath.startsWith('http')) {
        await client.sendImage(
          config.sessionId!,
          chatId,
          url: imagePath,
          caption: message,
        );
      } else {
        // Local file paths require base64 encoding — fall back to text
        debugPrint(
          '[MarketingWA] Local image path not supported via API, sending text only',
        );
        await client.sendText(config.sessionId!, chatId, message);
      }

      debugPrint('[MarketingWA] ✔ Sent image message to $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('[MarketingWA] Image send failed: $e, falling back to text');
      return sendMessage(phoneNumber: phoneNumber, message: message);
    }
  }

  /// Check if WhatsApp is available (either via OpenWA or URL scheme).
  Future<bool> isWhatsAppInstalled() async {
    // Check OpenWA availability first
    try {
      final tenant = _tenant;
      if (tenant != null) {
        final connected = await tenant.isConnected();
        if (connected) return true;
      }
    } catch (_) {}

    // Fallback to URL scheme check
    try {
      final Uri testUrl = Uri.parse('https://wa.me/911234567890');
      return await canLaunchUrl(testUrl);
    } catch (e) {
      return false;
    }
  }

  /// Fill template placeholders with actual values.
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

  /// Create a payment reminder message.
  String createPaymentReminder({
    required String customerName,
    required String shopName,
    required double amount,
    DateTime? dueDate,
  }) {
    final message =
        '''नमस्ते $customerName,

आपके $shopName से ₹${amount.toStringAsFixed(0)} का भुगतान बाकी है।

${dueDate != null ? 'भुगतान तिथि: ${dueDate.day}/${dueDate.month}/${dueDate.year}' : ''}

कृपया जल्द से जल्द भुगतान करें।

धन्यवाद!''';

    return message.trim();
  }

  /// Send bulk WhatsApp messages via OpenWA's batch endpoint.
  ///
  /// Uses OpenWA's send-bulk API for efficient batch delivery with progress
  /// tracking. Falls back to sequential URL-scheme sends if OpenWA is unavailable.
  Stream<(String phone, bool success)> sendBulkMessages({
    required List<String> phoneNumbers,
    required String message,
    Duration delay = const Duration(seconds: 2),
  }) async* {
    // Try OpenWA bulk send (preferred — single API call with batch tracking)
    final tenant = _tenant;
    if (tenant != null) {
      try {
        final connected = await tenant.isConnected();
        if (connected) {
          final config = await tenant.getBusinessConfig();
          final client = await tenant.getClient();

          final messages = phoneNumbers.map((phone) => {
            'chatId': _formatChatId(phone),
            'text': message,
          }).toList();

          final batch = await client.sendBulk(
            config.sessionId!,
            messages,
          );

          final batchId = batch['batchId'] as String?;
          if (batchId != null) {
            debugPrint('[MarketingWA] ✔ Bulk send initiated: $batchId');
            // Yield success for all numbers (batch is processing server-side)
            for (final phone in phoneNumbers) {
              yield (phone, true);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('[MarketingWA] Bulk send failed: $e, falling back to sequential');
      }
    }

    // Fallback to sequential URL-scheme sends
    for (final phone in phoneNumbers) {
      final success = await sendMessage(phoneNumber: phone, message: message);
      yield (phone, success);
      await Future.delayed(delay);
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Send via OpenWA API gateway.
  Future<bool> _sendViaOpenWA(String phone, String message) async {
    try {
      final tenant = _tenant;
      if (tenant == null) return false;

      final connected = await tenant.isConnected();
      if (!connected) return false;

      final config = await tenant.getBusinessConfig();
      final client = await tenant.getClient();
      final chatId = _formatChatId(phone);

      await client.sendText(config.sessionId!, chatId, message);
      debugPrint('[MarketingWA] ✔ Sent via OpenWA to $phone');
      return true;
    } catch (e) {
      debugPrint('[MarketingWA] OpenWA send failed: $e');
      return false;
    }
  }

  /// Fallback: send via wa.me URL scheme (opens native WhatsApp).
  Future<bool> _sendViaUrlScheme(String phone, String message) async {
    try {
      final cleanNumber = _cleanPhoneNumber(phone);
      final encodedMessage = Uri.encodeComponent(message);
      final Uri whatsappUrl = Uri.parse(
        'https://wa.me/$cleanNumber?text=$encodedMessage',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        debugPrint('[MarketingWA] Opened WhatsApp URL for $cleanNumber');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[MarketingWA] URL scheme fallback failed: $e');
      return false;
    }
  }

  /// Format phone number to WhatsApp chat ID format.
  String _formatChatId(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final withCountry = digits.length == 10 ? '91$digits' : digits;
    return '$withCountry@s.whatsapp.net';
  }

  /// Clean and format phone number.
  String _cleanPhoneNumber(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length == 10) clean = '91$clean';
    if (clean.startsWith('0')) clean = '91${clean.substring(1)}';
    return clean;
  }

  /// Safely resolve tenant service (returns null if not registered).
  OpenWATenantService? _resolveTenantService() {
    try {
      if (sl.isRegistered<OpenWATenantService>()) {
        return sl<OpenWATenantService>();
      }
      return OpenWATenantService();
    } catch (_) {
      return null;
    }
  }
}
