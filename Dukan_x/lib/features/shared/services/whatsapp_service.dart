import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/openwa/openwa_client.dart';
import '../../../../core/openwa/openwa_tenant_service.dart';

/// WhatsApp Integration Service
///
/// Handles sharing PDF invoices via WhatsApp through multiple channels:
/// 1. **OpenWA API** (preferred) — uses the integrated WhatsApp gateway
/// 2. **URL Launch** — fallback for devices with WhatsApp installed
/// 3. **Backend API** — for bulk/automated sending via DukanX backend
///
/// The service attempts OpenWA first (if connected), then falls back to
/// native URL launching. The backend API is used for automated workflows
/// (e.g., scheduled payment reminders).
class WhatsAppService {
  final ApiClient _api = sl<ApiClient>();
  OpenWATenantService? _tenantService;

  /// Lazy-initialize tenant service (may not be available in all contexts).
  OpenWATenantService? get _tenant {
    _tenantService ??= _resolveTenantService();
    return _tenantService;
  }

  // ── Primary Send Methods ──────────────────────────────────────────────────

  /// Send a text message via the best available channel.
  ///
  /// Tries: OpenWA → URL launcher → returns false.
  Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    // 1. Try OpenWA API first (if configured and connected)
    final sent = await _sendViaOpenWA(phone, message);
    if (sent) return true;

    // 2. Fallback to native URL launcher
    return shareToWhatsAppLocally(phone: phone, message: message);
  }

  /// Send an invoice document via WhatsApp.
  ///
  /// Tries: OpenWA (document) → Backend API → URL launcher with link.
  Future<bool> sendInvoice({
    required String businessId,
    required String customerPhone,
    required String invoiceId,
    required String invoiceUrl,
    String? customerName,
    String? amount,
  }) async {
    // 1. Try OpenWA API — send document directly
    final sentViaGateway = await _sendInvoiceViaOpenWA(
      customerPhone: customerPhone,
      invoiceUrl: invoiceUrl,
      invoiceId: invoiceId,
      customerName: customerName,
      amount: amount,
    );
    if (sentViaGateway) return true;

    // 2. Try backend API
    final sentViaBackend = await sendInvoiceViaApi(
      businessId: businessId,
      customerPhone: customerPhone,
      invoiceId: invoiceId,
      invoiceUrl: invoiceUrl,
    );
    if (sentViaBackend) return true;

    // 3. Fallback to URL launcher with invoice link
    final message = 'Here is your invoice #$invoiceId: $invoiceUrl';
    return shareToWhatsAppLocally(phone: customerPhone, message: message);
  }

  /// Send a payment reminder via WhatsApp.
  Future<bool> sendPaymentReminder({
    required String customerPhone,
    required String customerName,
    required String amount,
    required String dueDate,
    String? invoiceNumber,
  }) async {
    final message = 'Dear $customerName,\n\n'
        'This is a friendly reminder that your payment of ₹$amount'
        '${invoiceNumber != null ? ' for invoice #$invoiceNumber' : ''} '
        'is due on $dueDate.\n\n'
        'Please make the payment at your earliest convenience.\n\n'
        'Thank you!';

    return sendMessage(phone: customerPhone, message: message);
  }

  // ── Legacy URL Launcher (preserved) ───────────────────────────────────────

  /// Launch native WhatsApp with a pre-filled message (Direct to client's phone)
  static Future<bool> shareToWhatsAppLocally({
    required String phone,
    required String message,
  }) async {
    // Format phone: remove spaces/non-digits, ensure country code.
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeFull(message)}');
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Fallback to wa.me standard link
    final fallbackUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeFull(message)}');
    if (await canLaunchUrl(fallbackUri)) {
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ── Backend API (preserved) ───────────────────────────────────────────────

  /// Send Invoice Link via Backend WhatsApp Business API
  Future<bool> sendInvoiceViaApi({
    required String businessId,
    required String customerPhone,
    required String invoiceId,
    required String invoiceUrl,
  }) async {
    try {
      final res = await _api.post('/whatsapp/send-invoice', body: {
        'businessId': businessId,
        'phone': customerPhone,
        'invoiceId': invoiceId,
        'invoiceUrl': invoiceUrl,
      });
      return res.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // ── OpenWA API Internals ──────────────────────────────────────────────────

  /// Send a text message via OpenWA gateway.
  Future<bool> _sendViaOpenWA(String phone, String message) async {
    try {
      final tenant = _tenant;
      if (tenant == null) return false;

      final config = await tenant.getBusinessConfig();
      if (!config.isProvisioned || !config.isConnected) return false;

      final client = await tenant.getClient();
      final chatId = _formatChatId(phone);

      await client.sendText(config.sessionId!, chatId, message);
      debugPrint('[WhatsAppService] ✔ Sent via OpenWA to $phone');
      return true;
    } catch (e) {
      debugPrint('[WhatsAppService] OpenWA send failed: $e');
      return false;
    }
  }

  /// Send an invoice document via OpenWA gateway.
  Future<bool> _sendInvoiceViaOpenWA({
    required String customerPhone,
    required String invoiceUrl,
    required String invoiceId,
    String? customerName,
    String? amount,
  }) async {
    try {
      final tenant = _tenant;
      if (tenant == null) return false;

      final config = await tenant.getBusinessConfig();
      if (!config.isProvisioned || !config.isConnected) return false;

      final client = await tenant.getClient();
      final chatId = _formatChatId(customerPhone);

      final caption = 'Invoice #$invoiceId'
          '${customerName != null ? ' for $customerName' : ''}'
          '${amount != null ? '\nAmount: ₹$amount' : ''}';

      await client.sendDocument(
        config.sessionId!,
        chatId,
        url: invoiceUrl,
        filename: 'invoice_$invoiceId.pdf',
        caption: caption,
      );

      debugPrint('[WhatsAppService] ✔ Invoice sent via OpenWA to $customerPhone');
      return true;
    } catch (e) {
      debugPrint('[WhatsAppService] OpenWA invoice send failed: $e');
      return false;
    }
  }

  /// Format phone number to WhatsApp chat ID format.
  String _formatChatId(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    // Add India country code if not present
    final withCountry = digits.length == 10 ? '91$digits' : digits;
    return '$withCountry@s.whatsapp.net';
  }

  /// Safely resolve tenant service (returns null if not registered).
  OpenWATenantService? _resolveTenantService() {
    try {
      return OpenWATenantService();
    } catch (_) {
      return null;
    }
  }
}
