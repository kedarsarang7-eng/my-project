import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/di/service_locator.dart';
import '../models/bill.dart';
import 'gmail_service.dart';

class EmailRepository {
  static final EmailRepository _instance = EmailRepository._internal();
  factory EmailRepository() => _instance;
  EmailRepository._internal();

  // Migrated from cloud_functions to API Gateway
  ApiClient get _api => sl<ApiClient>();
  final GmailService _gmailService = GmailService();

  /// Send Invoice Email via Backend using Client-Side Access Token
  Future<void> sendInvoiceEmail({
    required Uint8List pdfBytes,
    required Bill bill,
    required String businessName,
  }) async {
    try {
      // 1. Check Authentication
      if (!await _gmailService.isAuthenticated()) {
        throw Exception('Gmail not connected. Please sign in first.');
      }

      // 2. Get Fresh Access Token
      final accessToken = await _gmailService.getAccessToken();

      // 3. Prepare Data
      final pdfBase64 = base64Encode(pdfBytes);
      final senderEmail = _gmailService.userEmail;

      if (bill.customerEmail == null || bill.customerEmail!.isEmpty) {
        throw Exception('Customer email not provided in the bill.');
      }

      // 4. Build email content
      final subject = 'Invoice #${bill.invoiceNumber} from $businessName';
      final body = '''
Hello ${bill.customerName},

Please find attached the invoice #${bill.invoiceNumber} for your recent purchase at $businessName.

Invoice Details:
Number: ${bill.invoiceNumber}
Date: ${bill.date.toString().split(' ')[0]}
Amount: ₹${bill.grandTotal.toStringAsFixed(2)}

Thank you for your business!

Regards,
$businessName
''';

      // 5. Call API Gateway endpoint (replaces Cloud Function)
      final result = await _api.post('/api/v1/email/send-invoice', body: {
        'recipient': bill.customerEmail,
        'subject': subject,
        'body': body,
        'pdfBase64': pdfBase64,
        'filename': 'Invoice_${bill.invoiceNumber}.pdf',
        'accessToken': accessToken,
        'senderEmail': senderEmail,
        'businessName': businessName,
      });

      if (!result.isSuccess) {
        throw Exception('Server failed to send email: ${result.error}');
      }

      final Map? data = result.data is Map ? result.data as Map : null;
      final messageId = data?['messageId'];
      debugPrint(
        '[EmailRepository] Email sent successfully. ID: $messageId',
      );
    } catch (e) {
      debugPrint('[EmailRepository] Failed to send email: $e');
      rethrow;
    }
  }
}
