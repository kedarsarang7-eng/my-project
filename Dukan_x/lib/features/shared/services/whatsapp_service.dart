import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

/// WhatsApp Integration Service
/// Handles sharing PDF invoices via WhatsApp, both natively on device
/// (using URL launch) and via Backend API for bulk/automated sending.
class WhatsAppService {
  final ApiClient _api = sl<ApiClient>();

  /// 1. Launch native WhatsApp with a pre-filled message (Direct to client's phone)
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

  /// 2. Send Invoice Link via Backend WhatsApp Business API
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
}
