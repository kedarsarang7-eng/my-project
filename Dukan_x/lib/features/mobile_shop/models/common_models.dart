/// Common Shared Types — MobileShop Domain Models (Dart)
///
/// Shared primitives: tenant context wire format, money in integer minor units,
/// Data_Model_Version, and business-type normalization.
///
/// Requirements: 6.18, 6.33; GR-2
library;

import 'package:flutter/foundation.dart';

// ─── Business-Type Normalization ─────────────────────────────────────────────

/// Canonical wire value for mobile shop business type.
const String canonicalBusinessType = 'mobile_shop';

/// Known aliases that must be normalized at boundaries.
const Set<String> _businessTypeAliases = {
  'mobileShop',
  'mobileshop',
  'mobile_shop',
  'MobileShop',
  'MOBILESHOP',
  'MOBILE_SHOP',
};

/// Normalizes any known mobile shop alias to canonical `mobile_shop`.
/// Returns `null` if the input is not a mobile shop alias.
String? normalizeMobileShopBusinessType(String raw) {
  if (_businessTypeAliases.contains(raw) ||
      raw.toLowerCase() == 'mobileshop' ||
      raw.toLowerCase() == 'mobile_shop') {
    return canonicalBusinessType;
  }
  return null;
}

/// Returns true if the raw value represents a mobile shop business type.
bool isMobileShopBusinessType(String raw) {
  return normalizeMobileShopBusinessType(raw) != null;
}

// ─── Money (Integer Minor Units) ─────────────────────────────────────────────

/// Money representation using integer minor units (paise for INR).
@immutable
class Money {
  /// Amount in minor units (e.g. paise). Always a non-negative integer.
  final int amountMinorUnits;

  /// ISO 4217 currency code.
  final String currency;

  const Money({required this.amountMinorUnits, required this.currency});

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    amountMinorUnits: json['amountMinorUnits'] as int,
    currency: json['currency'] as String,
  );

  Map<String, dynamic> toJson() => {
    'amountMinorUnits': amountMinorUnits,
    'currency': currency,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          amountMinorUnits == other.amountMinorUnits &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(amountMinorUnits, currency);

  @override
  String toString() => 'Money($amountMinorUnits $currency)';
}

// ─── Tenant Context (Wire Format) ───────────────────────────────────────────

/// Tenant context resolved from authenticated claims.
@immutable
class TenantContextWire {
  final String tenantId;
  final String businessId;
  final String subjectId;
  final String businessType;
  final List<String> permissions;
  final String correlationId;

  const TenantContextWire({
    required this.tenantId,
    required this.businessId,
    required this.subjectId,
    required this.businessType,
    required this.permissions,
    required this.correlationId,
  });

  factory TenantContextWire.fromJson(Map<String, dynamic> json) =>
      TenantContextWire(
        tenantId: json['tenantId'] as String,
        businessId: json['businessId'] as String,
        subjectId: json['subjectId'] as String,
        businessType:
            normalizeMobileShopBusinessType(json['businessType'] as String) ??
            json['businessType'] as String,
        permissions: (json['permissions'] as List<dynamic>).cast<String>(),
        correlationId: json['correlationId'] as String,
      );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'businessId': businessId,
    'subjectId': subjectId,
    'businessType': businessType,
    'permissions': permissions,
    'correlationId': correlationId,
  };
}

// ─── Evidence Reference ──────────────────────────────────────────────────────

/// Reference to evidence stored in approved object storage.
@immutable
class EvidenceReference {
  final String referenceId;
  final String storageKey;
  final String contentType;
  final String digest;
  final String uploadedAt;

  const EvidenceReference({
    required this.referenceId,
    required this.storageKey,
    required this.contentType,
    required this.digest,
    required this.uploadedAt,
  });

  factory EvidenceReference.fromJson(Map<String, dynamic> json) =>
      EvidenceReference(
        referenceId: json['referenceId'] as String,
        storageKey: json['storageKey'] as String,
        contentType: json['contentType'] as String,
        digest: json['digest'] as String,
        uploadedAt: json['uploadedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
    'referenceId': referenceId,
    'storageKey': storageKey,
    'contentType': contentType,
    'digest': digest,
    'uploadedAt': uploadedAt,
  };
}

// ─── Paginated Response ──────────────────────────────────────────────────────

/// Generic paginated response wrapper.
@immutable
class PaginatedResponse<T> {
  final List<T> items;
  final String? continuationToken;
  final bool hasMore;

  const PaginatedResponse({
    required this.items,
    this.continuationToken,
    required this.hasMore,
  });
}
