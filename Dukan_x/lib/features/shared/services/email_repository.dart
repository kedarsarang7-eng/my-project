import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../models/bill.dart';
import '../../../../features/auth/services/gmail_service.dart';

class EmailRepository {
  static final EmailRepository _instance = EmailRepository._internal();
  factory EmailRepository() => _instance;
  EmailRepository._internal();

  final GmailService _gmailService = GmailService();

  /// API base URL from centralized config
  String get _apiBaseUrl => ApiConfig.baseUrl;

  /// Send Invoice Email via AWS Backend API
  ///
  /// Migrated from Firebase Cloud Functions to AWS Lambda endpoint.
  /// Uses HTTP POST instead of Firebase `httpsCallable`.
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

      // 4. Call AWS Lambda via API Gateway (replaces Cloud Functions)
      final subject = 'Invoice #${bill.invoiceNumber} from $businessName';
      final body =
          '''
Hello ${bill.customerName},

Please find attached the invoice #${bill.invoiceNumber} for your recent purchase at $businessName.

Invoice Details:
Number: ${bill.invoiceNumber}
Date: ${bill.date.toString().split(' ')[0]}
Amount: ?${bill.grandTotal.toStringAsFixed(2)}

Thank you for your business!

Regards,
$businessName
''';

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/email/send-invoice'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'recipient': bill.customerEmail,
          'subject': subject,
          'body': body,
          'pdfBase64': pdfBase64,
          'filename': 'Invoice_${bill.invoiceNumber}.pdf',
          'accessToken': accessToken,
          'senderEmail': senderEmail,
          'businessName': businessName,
        }),
      );

      if (response.statusCode != 200) {
        final responseData = jsonDecode(response.body);
        throw Exception(
          'Server failed to send email: ${responseData['message'] ?? response.body}',
        );
      }

      final responseData = jsonDecode(response.body);
      LoggerService.d('EmailRepo', 
        '[EmailRepository] Email sent successfully. ID: ${responseData['messageId']}',
      );
    } catch (e) {
      LoggerService.d('EmailRepo', '[EmailRepository] Failed to send email: $e');
      rethrow;
    }
  }
}
