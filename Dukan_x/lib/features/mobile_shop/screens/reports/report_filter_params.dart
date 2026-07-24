/// MobileShop Report Filter Params — Query Parameter Model (Dart)
///
/// Encapsulates filter parameters that can be passed to report views
/// via query parameters (from KPI card taps or direct navigation).
/// This enables exact KPI-to-filter navigation: a user taps a KPI card
/// and lands on the exact report with the pre-applied filter.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/foundation.dart';

/// Filter parameters extracted from query parameters for report views.
///
/// Used for KPI-to-filter navigation: when a user taps a KPI card, the
/// card's [filterRoute] and [filterParams] are encoded as query parameters
/// and decoded into this model by the report screen.
@immutable
class ReportFilterParams {
  /// Lifecycle state filter (e.g., 'IN_STOCK', 'RETURNED', 'DEMO').
  final String? lifecycle;

  /// Status filter (e.g., 'active', 'pending', 'failed').
  final String? status;

  /// Claim status filter (e.g., 'open', 'resolved').
  final String? claimStatus;

  /// Brand filter for brand/model reports.
  final String? brand;

  /// Model filter for brand/model reports.
  final String? model;

  /// Date range start (ISO 8601).
  final String? fromDate;

  /// Date range end (ISO 8601).
  final String? toDate;

  const ReportFilterParams({
    this.lifecycle,
    this.status,
    this.claimStatus,
    this.brand,
    this.model,
    this.fromDate,
    this.toDate,
  });

  /// Creates from URI query parameters.
  factory ReportFilterParams.fromQueryParameters(Map<String, String> params) {
    return ReportFilterParams(
      lifecycle: params['lifecycle'],
      status: params['status'],
      claimStatus: params['claimStatus'],
      brand: params['brand'],
      model: params['model'],
      fromDate: params['from'],
      toDate: params['to'],
    );
  }

  /// Whether any filter is actively applied.
  bool get hasActiveFilters =>
      lifecycle != null ||
      status != null ||
      claimStatus != null ||
      brand != null ||
      model != null ||
      fromDate != null ||
      toDate != null;

  /// Returns a human-readable description of active filters.
  String get activeFilterDescription {
    final parts = <String>[];
    if (lifecycle != null) parts.add('Lifecycle: $lifecycle');
    if (status != null) parts.add('Status: $status');
    if (claimStatus != null) parts.add('Claims: $claimStatus');
    if (brand != null) parts.add('Brand: $brand');
    if (model != null) parts.add('Model: $model');
    if (fromDate != null || toDate != null) {
      parts.add('Date: ${fromDate ?? '…'} → ${toDate ?? '…'}');
    }
    return parts.join(' • ');
  }

  /// Converts to query parameters map for navigation.
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (lifecycle != null) params['lifecycle'] = lifecycle!;
    if (status != null) params['status'] = status!;
    if (claimStatus != null) params['claimStatus'] = claimStatus!;
    if (brand != null) params['brand'] = brand!;
    if (model != null) params['model'] = model!;
    if (fromDate != null) params['from'] = fromDate!;
    if (toDate != null) params['to'] = toDate!;
    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilterParams &&
          lifecycle == other.lifecycle &&
          status == other.status &&
          claimStatus == other.claimStatus &&
          brand == other.brand &&
          model == other.model &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => Object.hash(
    lifecycle,
    status,
    claimStatus,
    brand,
    model,
    fromDate,
    toDate,
  );
}
