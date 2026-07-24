/// MobileCommerceService — Application Service for Commerce UI Flows
///
/// Provides a unified interface for finance, SIM/recharge, OCR, bundle,
/// and price-adjustment operations. Routes operations through the consistency
/// orchestrator, respects offline eligibility, and gates capabilities by
/// feature policy.
///
/// Requirements: 7.3, 10.1–10.12, 12.1–12.8
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/tenant_context.dart';
import '../../billing/mobile_sale_consistency_orchestrator.dart';
import '../../config/feature_policy_config.dart';
import '../../config/offline_eligibility_config.dart';
import '../../models/common_models.dart';
import '../../models/finance_models.dart';
import '../../models/recharge_models.dart';

// ─── Commerce Operation Result ───────────────────────────────────────────────

/// Outcome of a commerce operation: mirrors consistency orchestrator states
/// but adds domain-specific context for each flow.
enum CommerceOutcomeState {
  /// Operation completed successfully (backend confirmed).
  success,

  /// Operation accepted but pending provider/backend verification.
  pending,

  /// Provider returned ambiguous result — awaiting reconciliation.
  ambiguous,

  /// Operation rejected by validation or provider.
  rejected,

  /// Offline: data preserved locally, will submit when online.
  offlinePreserved,

  /// Feature is disabled by policy.
  featureDisabled,

  /// Online connectivity required but unavailable.
  connectivityRequired,
}

/// Result of a commerce operation with provider-neutral outcome.
@immutable
class CommerceOutcome {
  final CommerceOutcomeState state;
  final String operationId;
  final String? providerRequestId;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? responseData;

  const CommerceOutcome({
    required this.state,
    required this.operationId,
    this.providerRequestId,
    this.errorCode,
    this.errorMessage,
    this.responseData,
  });

  bool get isSuccess => state == CommerceOutcomeState.success;
  bool get isPending =>
      state == CommerceOutcomeState.pending ||
      state == CommerceOutcomeState.ambiguous;
  bool get isOffline => state == CommerceOutcomeState.offlinePreserved;
  bool get isDisabled => state == CommerceOutcomeState.featureDisabled;
}

// ─── Application Service Interface ───────────────────────────────────────────

/// Provider-neutral commerce service interface.
///
/// All operations gate by feature policy before submission. Operations that
/// require online connectivity will return [CommerceOutcomeState.connectivityRequired]
/// when offline, with entered data preserved for retry.
abstract interface class MobileCommerceService {
  /// Check if a feature is enabled by policy for the current tenant.
  bool isFeatureEnabled(String featureId);

  /// Submit a finance plan application.
  Future<CommerceOutcome> submitFinancePlan(
    TenantContext context,
    FinancePlanRequest request,
  );

  /// Submit a SIM/recharge transaction.
  Future<CommerceOutcome> submitRecharge(
    TenantContext context,
    RechargeRequest request,
  );

  /// Submit an OCR scan for processing.
  Future<CommerceOutcome> submitOcrScan(
    TenantContext context,
    OcrScanRequest request,
  );

  /// Submit a bundle sale.
  Future<CommerceOutcome> submitBundleSale(
    TenantContext context,
    BundleSaleRequest request,
  );

  /// Submit a price adjustment.
  Future<CommerceOutcome> submitPriceAdjustment(
    TenantContext context,
    PriceAdjustmentRequest request,
  );

  /// Check status of a pending commerce operation.
  Future<CommerceOutcome> checkOperationStatus(
    TenantContext context,
    String operationId,
  );
}

// ─── Request Models ──────────────────────────────────────────────────────────

/// Finance plan application request.
@immutable
class FinancePlanRequest {
  final String customerId;
  final String customerName;
  final String invoiceId;
  final String imei;
  final String unitId;
  final String provider;
  final int principalAmountMinor;
  final int downPaymentMinor;
  final int interestRateBasisPoints;
  final int tenureMonths;
  final String currency;
  final String? consentReference;
  final String? notes;

  const FinancePlanRequest({
    required this.customerId,
    required this.customerName,
    required this.invoiceId,
    required this.imei,
    required this.unitId,
    required this.provider,
    required this.principalAmountMinor,
    required this.downPaymentMinor,
    required this.interestRateBasisPoints,
    required this.tenureMonths,
    required this.currency,
    this.consentReference,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'customerName': customerName,
    'invoiceId': invoiceId,
    'imei': imei,
    'unitId': unitId,
    'provider': provider,
    'principalAmountMinor': principalAmountMinor,
    'downPaymentMinor': downPaymentMinor,
    'interestRateBasisPoints': interestRateBasisPoints,
    'tenureMonths': tenureMonths,
    'currency': currency,
    if (consentReference != null) 'consentReference': consentReference,
    if (notes != null) 'notes': notes,
  };
}

/// SIM/Recharge request.
@immutable
class RechargeRequest {
  final String mobileNumber;
  final RechargeType rechargeType;
  final String provider;
  final String planId;
  final int amountMinor;
  final String currency;
  final String? customerId;

  const RechargeRequest({
    required this.mobileNumber,
    required this.rechargeType,
    required this.provider,
    required this.planId,
    required this.amountMinor,
    required this.currency,
    this.customerId,
  });

  Map<String, dynamic> toJson() => {
    'mobileNumber': mobileNumber,
    'rechargeType': rechargeType.toWireValue(),
    'provider': provider,
    'planId': planId,
    'amountMinor': amountMinor,
    'currency': currency,
    if (customerId != null) 'customerId': customerId,
  };
}

/// OCR scan request.
@immutable
class OcrScanRequest {
  final String imageReference;
  final String contentType;
  final String ocrFocus; // e.g. 'invoice', 'receipt', 'imei_label'
  final Map<String, dynamic>? metadata;

  const OcrScanRequest({
    required this.imageReference,
    required this.contentType,
    required this.ocrFocus,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'imageReference': imageReference,
    'contentType': contentType,
    'ocrFocus': ocrFocus,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Bundle sale request with separate stock/tax/accounting lines.
@immutable
class BundleSaleRequest {
  final String customerId;
  final String invoiceId;
  final List<BundleLineItem> lines;
  final int? discountMinor;
  final String? loyaltyReference;
  final String currency;

  const BundleSaleRequest({
    required this.customerId,
    required this.invoiceId,
    required this.lines,
    this.discountMinor,
    this.loyaltyReference,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'invoiceId': invoiceId,
    'lines': lines.map((l) => l.toJson()).toList(),
    if (discountMinor != null) 'discountMinor': discountMinor,
    if (loyaltyReference != null) 'loyaltyReference': loyaltyReference,
    'currency': currency,
  };
}

/// A line item in a bundle sale.
@immutable
class BundleLineItem {
  final String productId;
  final String productName;
  final String lineType; // 'handset', 'accessory', 'service'
  final String? imei;
  final int unitPriceMinor;
  final int quantity;
  final int taxMinor;
  final String taxCategory;
  final String accountingCode;

  const BundleLineItem({
    required this.productId,
    required this.productName,
    required this.lineType,
    this.imei,
    required this.unitPriceMinor,
    required this.quantity,
    required this.taxMinor,
    required this.taxCategory,
    required this.accountingCode,
  });

  int get totalMinor => unitPriceMinor * quantity + taxMinor;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'lineType': lineType,
    if (imei != null) 'imei': imei,
    'unitPriceMinor': unitPriceMinor,
    'quantity': quantity,
    'taxMinor': taxMinor,
    'taxCategory': taxCategory,
    'accountingCode': accountingCode,
  };
}

/// Price adjustment request.
@immutable
class PriceAdjustmentRequest {
  final String unitId;
  final String imei;
  final String adjustmentType; // 'markdown', 'price_protection', 'promotional'
  final int originalPriceMinor;
  final int adjustedPriceMinor;
  final String reason;
  final String? approvedBy;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String currency;

  const PriceAdjustmentRequest({
    required this.unitId,
    required this.imei,
    required this.adjustmentType,
    required this.originalPriceMinor,
    required this.adjustedPriceMinor,
    required this.reason,
    this.approvedBy,
    this.effectiveFrom,
    this.effectiveTo,
    required this.currency,
  });

  /// Margin impact in minor units (negative = margin reduction).
  int get marginImpactMinor => adjustedPriceMinor - originalPriceMinor;

  Map<String, dynamic> toJson() => {
    'unitId': unitId,
    'imei': imei,
    'adjustmentType': adjustmentType,
    'originalPriceMinor': originalPriceMinor,
    'adjustedPriceMinor': adjustedPriceMinor,
    'reason': reason,
    if (approvedBy != null) 'approvedBy': approvedBy,
    if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
    if (effectiveTo != null) 'effectiveTo': effectiveTo,
    'currency': currency,
  };
}

// ─── Implementation ──────────────────────────────────────────────────────────

/// Default implementation routing through the consistency orchestrator.
class MobileCommerceServiceImpl implements MobileCommerceService {
  final MobileSaleConsistencyOrchestrator _orchestrator;
  final FeaturePolicyConfig _featurePolicy;
  final OfflineEligibilityConfig _offlineConfig;

  static const _uuid = Uuid();

  MobileCommerceServiceImpl({
    required MobileSaleConsistencyOrchestrator orchestrator,
    FeaturePolicyConfig featurePolicy = kFeaturePolicyConfig,
    OfflineEligibilityConfig offlineConfig = kOfflineEligibilityConfig,
  }) : _orchestrator = orchestrator,
       _featurePolicy = featurePolicy,
       _offlineConfig = offlineConfig;

  @override
  bool isFeatureEnabled(String featureId) {
    final feature = _featurePolicy.getFeature(featureId);
    return feature?.enabledByDefault ?? false;
  }

  @override
  Future<CommerceOutcome> submitFinancePlan(
    TenantContext context,
    FinancePlanRequest request,
  ) async {
    // Gate: feature policy check
    if (!isFeatureEnabled('FINANCE_PLANS')) {
      return CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Finance plans are not enabled for this tenant',
      );
    }

    // Gate: online required for finance
    if (!_offlineConfig.isOfflineEligible('FINANCE_PLAN_CREATE')) {
      // Will proceed to orchestrator which handles connectivity check
    }

    final operationId = generateOperationId();
    final payload = jsonEncode(request.toJson());
    final fingerprint = computeMutationFingerprint(
      'FINANCE_PLAN_CREATE',
      payload,
    );
    final providerRequestId = _uuid.v4();

    final command = MobileSaleCommand(
      operationId: operationId,
      mutationFingerprint: fingerprint,
      invoicePayload: {
        ...request.toJson(),
        'providerRequestId': providerRequestId,
      },
      deviceLines: [],
      expectedImeiVersions: {},
      dataModelVersion: 1,
    );

    final outcome = await _orchestrator.finalizeSale(context, command);
    return _mapOutcome(outcome, providerRequestId);
  }

  @override
  Future<CommerceOutcome> submitRecharge(
    TenantContext context,
    RechargeRequest request,
  ) async {
    if (!isFeatureEnabled('SIM_RECHARGE')) {
      return CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'SIM/Recharge is not enabled for this tenant',
      );
    }

    final operationId = generateOperationId();
    final payload = jsonEncode(request.toJson());
    final fingerprint = computeMutationFingerprint('SIM_RECHARGE', payload);
    final providerRequestId = _uuid.v4();

    final command = MobileSaleCommand(
      operationId: operationId,
      mutationFingerprint: fingerprint,
      invoicePayload: {
        ...request.toJson(),
        'providerRequestId': providerRequestId,
      },
      deviceLines: [],
      expectedImeiVersions: {},
      dataModelVersion: 1,
    );

    final outcome = await _orchestrator.finalizeSale(context, command);
    return _mapOutcome(outcome, providerRequestId);
  }

  @override
  Future<CommerceOutcome> submitOcrScan(
    TenantContext context,
    OcrScanRequest request,
  ) async {
    if (!isFeatureEnabled('OCR_INTAKE')) {
      return CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'OCR intake is not enabled for this tenant',
      );
    }

    final operationId = generateOperationId();
    final payload = jsonEncode(request.toJson());
    final fingerprint = computeMutationFingerprint('OCR_SCAN', payload);

    final command = MobileSaleCommand(
      operationId: operationId,
      mutationFingerprint: fingerprint,
      invoicePayload: request.toJson(),
      deviceLines: [],
      expectedImeiVersions: {},
      dataModelVersion: 1,
    );

    final outcome = await _orchestrator.finalizeSale(context, command);
    return _mapOutcome(outcome, null);
  }

  @override
  Future<CommerceOutcome> submitBundleSale(
    TenantContext context,
    BundleSaleRequest request,
  ) async {
    if (!isFeatureEnabled('BUNDLES')) {
      return CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Bundle sales are not enabled for this tenant',
      );
    }

    final operationId = generateOperationId();
    final payload = jsonEncode(request.toJson());
    final fingerprint = computeMutationFingerprint('BUNDLE_SALE', payload);

    // Extract IMEI lines for version tracking
    final imeiVersions = <String, int>{};
    final deviceLines = <DeviceLineItem>[];
    for (final line in request.lines) {
      if (line.imei != null) {
        imeiVersions[line.imei!] = 0; // Will be validated by backend
        deviceLines.add(
          DeviceLineItem(
            normalizedImei: line.imei!,
            productId: line.productId,
            salePriceMinor: line.unitPriceMinor,
          ),
        );
      }
    }

    final command = MobileSaleCommand(
      operationId: operationId,
      mutationFingerprint: fingerprint,
      invoicePayload: request.toJson(),
      deviceLines: deviceLines,
      expectedImeiVersions: imeiVersions,
      dataModelVersion: 1,
    );

    final outcome = await _orchestrator.finalizeSale(context, command);
    return _mapOutcome(outcome, null);
  }

  @override
  Future<CommerceOutcome> submitPriceAdjustment(
    TenantContext context,
    PriceAdjustmentRequest request,
  ) async {
    if (!isFeatureEnabled('PRICE_PROTECTION')) {
      return CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Price protection is not enabled for this tenant',
      );
    }

    final operationId = generateOperationId();
    final payload = jsonEncode(request.toJson());
    final fingerprint = computeMutationFingerprint('PRICE_ADJUSTMENT', payload);

    final command = MobileSaleCommand(
      operationId: operationId,
      mutationFingerprint: fingerprint,
      invoicePayload: request.toJson(),
      deviceLines: [],
      expectedImeiVersions: {request.imei: 0},
      dataModelVersion: 1,
    );

    final outcome = await _orchestrator.finalizeSale(context, command);
    return _mapOutcome(outcome, null);
  }

  @override
  Future<CommerceOutcome> checkOperationStatus(
    TenantContext context,
    String operationId,
  ) async {
    final outcome = await _orchestrator.checkStatus(context, operationId);
    return _mapOutcome(outcome, null);
  }

  // ─── Mapping ─────────────────────────────────────────────────────────────

  CommerceOutcome _mapOutcome(
    ConsistencyOutcome outcome,
    String? providerRequestId,
  ) {
    final CommerceOutcomeState state;
    switch (outcome.state) {
      case SaleOutcomeState.committed:
        state = CommerceOutcomeState.success;
      case SaleOutcomeState.acceptedPending:
      case SaleOutcomeState.localPending:
        state = CommerceOutcomeState.pending;
      case SaleOutcomeState.offlineQueued:
        state = CommerceOutcomeState.offlinePreserved;
      case SaleOutcomeState.conflict:
        state = CommerceOutcomeState.ambiguous;
      case SaleOutcomeState.rejected:
        state = CommerceOutcomeState.rejected;
    }

    return CommerceOutcome(
      state: state,
      operationId: outcome.operationId,
      providerRequestId: providerRequestId,
      errorCode: outcome.errorCode,
      errorMessage: outcome.errorMessage,
    );
  }
}
