/// MobileSaleImeiValidator — Required IMEI Validation Bridge for Billing
///
/// Provides the REQUIRED (non-null) IMEI validation dependency for
/// [BillsRepository] when the business type is mobileShop.
///
/// This replaces the nullable [imeiValidationService] parameter that
/// previously allowed guarded blocks to be skipped at runtime (AF-19).
///
/// For mobileShop tenants:
/// - Validation is MANDATORY — absence of this dependency at runtime is a
///   startup failure (fail-closed).
/// - Tenant context must resolve to mobile_shop or the call throws.
///
/// For non-mobileShop tenants:
/// - This class is not registered; their existing null handling is unchanged.
///
/// Requirements: 2.5–2.6, 3.12, 12.3
/// Audit: AF-19, AF-21, AF-37, AF-49
library;

import '../auth/tenant_context_resolver.dart';
import '../domain/imei_validator.dart';

// ─── Error type ──────────────────────────────────────────────────────────────

/// Thrown when a required mobile-shop billing dependency is absent or the
/// tenant context cannot be resolved at the point of use.
///
/// This is a programming/configuration error — the DI layer should prevent
/// it by failing at startup for mobileShop tenants.
class MobileShopDependencyError extends Error {
  /// Human-readable description of the missing dependency or context.
  final String message;

  MobileShopDependencyError(this.message);

  @override
  String toString() => 'MobileShopDependencyError: $message';
}

// ─── Validator bridge ────────────────────────────────────────────────────────

/// Bridge between billing (BillsRepository) and the authoritative IMEI
/// validation path defined in `domain/imei_validator.dart`.
///
/// Usage:
/// ```dart
/// final validator = MobileSaleImeiValidator(resolver: tenantContextResolver);
/// final result = validator.validateForSale('356938035643809');
/// ```
///
/// Fail-closed contract:
/// - If tenant context is absent → throws [MobileShopDependencyError]
/// - If business type is not mobile_shop → throws [MobileShopDependencyError]
/// - If IMEI fails local checks → returns [ImeiValidationFailure]
/// - If IMEI passes → returns [ImeiValidationSuccess]
class MobileSaleImeiValidator {
  final TenantContextResolver _resolver;

  /// Creates a validator bound to the given [TenantContextResolver].
  ///
  /// The resolver is used at validation time to enforce that the current
  /// session belongs to a mobile-shop tenant (fail-closed).
  const MobileSaleImeiValidator({required TenantContextResolver resolver})
    : _resolver = resolver;

  /// Validates an IMEI for a mobile-shop sale.
  ///
  /// Returns field-associated errors for UI display via [ImeiValidationResult].
  ///
  /// Throws [MobileShopDependencyError] if:
  /// - Tenant context cannot be resolved (session expired / unavailable)
  /// - Business type is not mobile_shop
  ///
  /// This ensures billing CANNOT silently skip IMEI validation for mobileShop
  /// tenants — the old nullable guard pattern (AF-19) is eliminated.
  ImeiValidationResult validateForSale(String? rawImei) {
    // 1. Require mobile-shop tenant context (fail closed)
    final contextResult = _resolver.requireMobileShop();
    switch (contextResult) {
      case TenantFailure(:final error):
        throw MobileShopDependencyError(
          'Tenant context required for IMEI validation: '
          '${error.message} (${error.code})',
        );
      case TenantSuccess():
        // Context is valid and confirmed as mobile_shop — proceed.
        break;
    }

    // 2. Run the authoritative validation (from task 5.1)
    //    This applies: required check, separator normalization, ASCII digits,
    //    15-digit length, and Luhn checksum — in documented precedence order.
    return validateImei(rawImei);
  }

  /// Validates a batch of IMEI strings for a sale with multiple device lines.
  ///
  /// Returns a list of results, one per input IMEI. The caller should check
  /// each result and accumulate errors for UI display.
  ///
  /// Throws [MobileShopDependencyError] on context failure (same as
  /// [validateForSale]).
  List<ImeiValidationResult> validateBatchForSale(List<String?> rawImeis) {
    // Context check runs once for the batch (fail-closed)
    final contextResult = _resolver.requireMobileShop();
    switch (contextResult) {
      case TenantFailure(:final error):
        throw MobileShopDependencyError(
          'Tenant context required for IMEI validation: '
          '${error.message} (${error.code})',
        );
      case TenantSuccess():
        break;
    }

    // Validate each IMEI independently
    return rawImeis.map(validateImei).toList();
  }
}
