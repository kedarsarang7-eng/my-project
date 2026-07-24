/// MobileShop TenantContext — Authoritative Identity Model (Dart)
///
/// Single source of truth for resolved tenant identity.
/// Every screen, repository, sync coordinator, and guard
/// MUST use this model rather than direct Firebase/Auth calls.
///
/// Requirements: 2.1–2.4, 5.8–5.9, 8.3–8.7
library;

import 'package:flutter/foundation.dart';

import 'business_type.dart';

/// The authoritative, immutable tenant identity resolved once per session.
///
/// Carries tenant, business, subject, permissions, and a per-resolution
/// correlation ID. Consumed by guards, repositories, sync, and API adapters.
@immutable
class TenantContext {
  /// The authenticated tenant identifier (owner/business ID).
  final String tenantId;

  /// The currently active business identifier.
  final String businessId;

  /// The authenticated subject (user UID).
  final String subjectId;

  /// The canonical business type (normalized at resolution time).
  final MobileShopBusinessType businessType;

  /// The expanded set of MobileShop permissions granted to this subject.
  final Set<String> permissions;

  /// A UUID v4 correlation ID generated at resolution time.
  /// Propagated through every downstream call for traceability.
  final String correlationId;

  const TenantContext({
    required this.tenantId,
    required this.businessId,
    required this.subjectId,
    required this.businessType,
    required this.permissions,
    required this.correlationId,
  });

  /// Whether the resolved business type is mobile shop.
  bool get isMobileShop => businessType.isMobileShop;

  /// Checks if a specific permission is granted (after manage-implies-view
  /// expansion).
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Checks if ALL of the specified permissions are granted.
  bool hasAllPermissions(Iterable<String> required) =>
      required.every(permissions.contains);

  /// Checks if ANY of the specified permissions are granted.
  bool hasAnyPermission(Iterable<String> required) =>
      required.any(permissions.contains);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantContext &&
          runtimeType == other.runtimeType &&
          tenantId == other.tenantId &&
          businessId == other.businessId &&
          subjectId == other.subjectId &&
          businessType == other.businessType &&
          correlationId == other.correlationId &&
          setEquals(permissions, other.permissions);

  @override
  int get hashCode => Object.hash(
    tenantId,
    businessId,
    subjectId,
    businessType,
    correlationId,
    Object.hashAll(permissions.toList()..sort()),
  );

  @override
  String toString() =>
      'TenantContext(tenant=$tenantId, business=$businessId, '
      'subject=$subjectId, type=${businessType.toWireValue}, '
      'correlation=$correlationId)';
}
