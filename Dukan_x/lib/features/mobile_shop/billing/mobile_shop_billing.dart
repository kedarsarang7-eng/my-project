/// MobileShop Billing — Barrel Export
///
/// Public API for mobile-shop billing integration. Import this file
/// to access the IMEI validation bridge, consistency orchestrator,
/// field controller, scan handler, billing widget, and DI registration utilities.
///
/// ## Contents
///
/// - [MobileSaleConsistencyOrchestrator] — Routes sale/cancel/return through
///   outbox and backend with authoritative confirmation semantics
/// - [MobileSaleConsistencyOrchestratorImpl] — Production implementation
/// - [MobileSaleImeiValidator] — Required IMEI validation bridge for billing
/// - [MobileShopDependencyError] — Error for missing dependencies (fail-closed)
/// - [registerMobileShopBillingDependencies] — DI registration function
/// - [assertMobileShopBillingReady] — Startup assertion helper
/// - [ImeiFieldController] — IMEI field validation and state controller
/// - [ImeiScanHandler] — Scan-to-bill integration handler
/// - [MobileBillImeiField] — Responsive IMEI input widget
/// - [ReconciliationStatusDisplay] — Widget for pending/confirmed/conflicted UI
///
/// ## Usage
///
/// ```dart
/// import 'package:dukanx/features/mobile_shop/billing/mobile_shop_billing.dart';
/// ```
///
/// Requirements: 2.5–2.6, 3.1–3.12, 7.2–7.6, 10.3, 11.7–11.8, 12.1–12.10
/// Audit: AF-19, AF-20, AF-21, AF-37, AF-49
library;

export 'imei_field_controller.dart' show ImeiFieldController;
export 'imei_scan_handler.dart'
    show
        ImeiScanHandler,
        ScanResult,
        ScanAccepted,
        ScanValidationError,
        ScanDuplicateRejected,
        ScanBusyRejected;
export 'mobile_bill_imei_field.dart' show MobileBillImeiField;
export 'mobile_sale_consistency_orchestrator.dart'
    show
        MobileSaleConsistencyOrchestrator,
        MobileSaleConsistencyOrchestratorImpl,
        MobileSaleCommand,
        MobileCancellationCommand,
        MobileReturnCommand,
        DeviceLineItem,
        ConsistencyOutcome,
        SaleOutcomeState,
        computeMutationFingerprint,
        generateOperationId;
export 'mobile_sale_imei_validator.dart'
    show MobileSaleImeiValidator, MobileShopDependencyError;
export 'mobile_shop_billing_bridge.dart'
    show registerMobileShopBillingDependencies, assertMobileShopBillingReady;
export 'reconciliation_status_display.dart'
    show ReconciliationStatusDisplay, confirmationStatusToOutcomeState;
