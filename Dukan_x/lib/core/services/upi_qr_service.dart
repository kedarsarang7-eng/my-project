import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// UPI QR Service
/// Handles generating UPI intent strings and rendering QR codes for invoices
class UpiQrService {
  /// Generate UPI Intent string
  static String generateUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? transactionNote,
    String? transactionReference,
  }) {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': payeeName,
        ...{'am': amount > 0 ? amount.toStringAsFixed(2) : null},
        'cu': 'INR', // Currency
        ...{'tn': transactionNote},
        ...{'tr': transactionReference},
      },
    );
    return uri.toString();
  }

  /// Launch UPI Intent natively (PhonePe, GPay, etc. handle this)
  static Future<bool> launchUpiApp(String upiUri) async {
    final uri = Uri.parse(upiUri);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Returns a Widget rendering the QR code for a given URI.
  static Widget buildUpiQrCode({
    required String upiUri,
    double size = 200.0,
  }) {
    return QrImageView(
      data: upiUri,
      version: QrVersions.auto,
      size: size,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }
}
