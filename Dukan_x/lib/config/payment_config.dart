// ============================================================================
// Payment Configuration for Flutter App
// ============================================================================

import '../config/api_config.dart';

class PaymentConfig {
  /// API Gateway base URL — delegates to centralized ApiConfig
  static String get apiBaseUrl => ApiConfig.baseUrl;

  /// Payment polling configuration
  static const Duration pollInterval = Duration(seconds: 3);
  static const Duration pollTimeout = Duration(minutes: 10);
  
  /// QR code expiry time (should match backend - 10 minutes)
  static const Duration qrExpiryDuration = Duration(minutes: 10);
  
  /// Maximum payment amount (₹1 lakh = 100,000)
  static const double maxPaymentAmount = 100000;
  
  /// Supported payment modes
  static const List<String> supportedModes = [
    'CASH',
    'UPI',
    'CARD',
    'ONLINE',
  ];
  
  /// Feature flags
  static const bool enableUPIPayments = true;
  static const bool enableCashPayments = true;
  static const bool enableCardPayments = true;
}
