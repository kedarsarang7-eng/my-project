// ============================================================================
// SECURITY INITIALIZATION EXTENSION
// ============================================================================
// Extends SecurityInitializationService with new security layer components.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../database/app_database.dart';
import '../repository/audit_repository.dart';
import '../repository/fraud_alert_repository.dart';
import '../session/session_manager.dart';
import '../security/services/owner_pin_service.dart';
import '../security/services/pin_verification_service.dart';
import '../security/services/fraud_detection_service.dart';
import '../security/services/cash_closing_service.dart';
import '../services/access_control_service.dart';
import '../services/period_lock_service.dart';
import '../services/session_management_service.dart';
import '../services/stock_security_service.dart';
import '../services/cash_closing_validation_service.dart';
import '../services/security_notification_service.dart';

/// Security Layer - All security services bundled together.
///
/// Use this class to initialize all security components at app startup.
class SecurityLayer {
  final OwnerPinService pinService;
  final PinVerificationService pinVerificationService;
  final FraudDetectionService fraudDetectionService;
  final FraudAlertRepository fraudAlertRepository;
  final CashClosingService cashClosingService;
  final CashClosingValidationService cashClosingValidationService;
  final AccessControlService accessControlService;
  final PeriodLockService periodLockService;
  final SessionManagementService sessionManagementService;
  final StockSecurityService stockSecurityService;
  final SecurityNotificationService notificationService;

  SecurityLayer._({
    required this.pinService,
    required this.pinVerificationService,
    required this.fraudDetectionService,
    required this.fraudAlertRepository,
    required this.cashClosingService,
    required this.cashClosingValidationService,
    required this.accessControlService,
    required this.periodLockService,
    required this.sessionManagementService,
    required this.stockSecurityService,
    required this.notificationService,
  });

  /// Initialize all security services.
  ///
  /// [notificationsSdk] (optional) is the Shared_SDK instance the security
  /// services use to publish UNS events (Phase 2 §11.8-§11.10). When null,
  /// security alerts still flow to the local FraudAlertRepository but no
  /// UNS event is emitted — useful for unit tests and offline-first
  /// bootstrap paths where the SDK has not yet been wired.
  static Future<SecurityLayer> initialize({
    required AppDatabase database,
    required AuditRepository auditRepository,
    required SessionManager sessionManager,
    uns.NotificationsSdk? notificationsSdk,
  }) async {
    debugPrint('SecurityLayer: Initializing...');

    // 1. Core PIN Service
    final pinService = OwnerPinService();

    // 2. PIN Verification Service
    final pinVerificationService = PinVerificationService(
      pinService: pinService,
      auditRepository: auditRepository,
    );

    // 3. Fraud Detection Service
    final fraudDetectionService = FraudDetectionService(
      database: database,
      pinService: pinService,
      auditRepository: auditRepository,
    );

    // 4. Fraud Alert Repository
    final fraudAlertRepository = FraudAlertRepository(
      database: database,
      auditRepository: auditRepository,
    );

    // 5. Cash Closing Service
    final cashClosingService = CashClosingService(
      pinService: pinService,
      fraudService: fraudDetectionService,
      auditRepository: auditRepository,
    );

    // 6. Cash Closing Validation Service
    final cashClosingValidationService = CashClosingValidationService(
      database: database,
    );

    // 7. Access Control Service
    final accessControlService = AccessControlService(
      sessionManager: sessionManager,
      auditRepository: auditRepository,
    );

    // 8. Period Lock Service
    final periodLockService = PeriodLockService(
      pinService: pinService,
      auditRepository: auditRepository,
    );

    // 9. Session Management Service
    final sessionManagementService = SessionManagementService(
      auditRepository: auditRepository,
    );

    // 10. Stock Security Service
    //     Receives the SDK so anomaly detections (T-SEC-3) emit the
    //     `system.security_stock.anomaly_detected` event directly. Stock
    //     anomaly does NOT flow through FraudDetectionService.fraudAlerts;
    //     it is detected inline in `logStockAdjustment`.
    final stockSecurityService = StockSecurityService(
      pinService: pinService,
      auditRepository: auditRepository,
      notificationsSdk: notificationsSdk,
    );

    // 11. Notification Service
    //     Bridges FraudDetectionService.fraudAlerts onto UNS via the SDK
    //     (T-SEC-1, T-SEC-2). Without an SDK the service still mirrors
    //     alerts to the local FraudAlertRepository.
    final notificationService = SecurityNotificationService(
      fraudService: fraudDetectionService,
      alertRepository: fraudAlertRepository,
      sdk: notificationsSdk,
    );
    notificationService.startListening();

    debugPrint('SecurityLayer: Initialized all services');

    return SecurityLayer._(
      pinService: pinService,
      pinVerificationService: pinVerificationService,
      fraudDetectionService: fraudDetectionService,
      fraudAlertRepository: fraudAlertRepository,
      cashClosingService: cashClosingService,
      cashClosingValidationService: cashClosingValidationService,
      accessControlService: accessControlService,
      periodLockService: periodLockService,
      sessionManagementService: sessionManagementService,
      stockSecurityService: stockSecurityService,
      notificationService: notificationService,
    );
  }

  /// Dispose all services
  void dispose() {
    notificationService.dispose();
    fraudDetectionService.dispose();
    sessionManagementService.dispose();
    debugPrint('SecurityLayer: Disposed');
  }
}
