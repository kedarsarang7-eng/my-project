// ============================================================================
// Day-End Cash Service — Sprint 1: Denomination-aware close
// ============================================================================
// Thin client over the new /cash-closings/* backend endpoints. Uses paise
// internally so there's no rupee/paise drift across the wire.
//
// Why a fresh service (instead of refactoring the legacy
// `core/security/services/cash_closing_service.dart`)?
//   - Legacy hits `/api/v1/cash-closings` (deprecated SLS Postgres backend).
//   - Legacy has no concept of denomination breakdown / preview.
//   - Keeping legacy untouched preserves any existing fraud-detection
//     linkage; this service is the path for the new screen.
// ============================================================================

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';

@immutable
class CashDenomination {
  /// Face value in paise (₹500 → 50000, ₹1 → 100).
  final int valuePaise;
  final int count;

  const CashDenomination({required this.valuePaise, required this.count});

  int get totalPaise => valuePaise * count;
  double get totalRupees => totalPaise / 100.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'valuePaise': valuePaise,
    'count': count,
  };

  factory CashDenomination.fromJson(Map<String, dynamic> json) =>
      CashDenomination(
        valuePaise: (json['valuePaise'] as num).toInt(),
        count: (json['count'] as num).toInt(),
      );
}

enum CashClosingStatus {
  matched,
  mismatchPending,
  mismatchApproved;

  static CashClosingStatus parse(String? wire) {
    switch (wire) {
      case 'matched':
        return CashClosingStatus.matched;
      case 'mismatch_pending':
        return CashClosingStatus.mismatchPending;
      case 'mismatch_approved':
        return CashClosingStatus.mismatchApproved;
      default:
        return CashClosingStatus.matched;
    }
  }

  String get label {
    switch (this) {
      case CashClosingStatus.matched:
        return 'Matched';
      case CashClosingStatus.mismatchPending:
        return 'Mismatch — pending approval';
      case CashClosingStatus.mismatchApproved:
        return 'Mismatch — approved';
    }
  }
}

@immutable
class CashClosingPreview {
  final String closingDate;
  final int expectedCashPaise;
  final int tolerancePaise;

  const CashClosingPreview({
    required this.closingDate,
    required this.expectedCashPaise,
    required this.tolerancePaise,
  });

  double get expectedCashRupees => expectedCashPaise / 100.0;
  double get toleranceRupees => tolerancePaise / 100.0;

  factory CashClosingPreview.fromJson(Map<String, dynamic> json) =>
      CashClosingPreview(
        closingDate: json['closingDate'] as String,
        expectedCashPaise: (json['expectedCashPaise'] as num).toInt(),
        tolerancePaise: (json['tolerancePaise'] as num).toInt(),
      );
}

@immutable
class CashClosingRecord {
  final String id;
  final String closingDate;
  final int expectedCashPaise;
  final int countedCashPaise;
  /// expected - counted. Positive = short, negative = over.
  final int variancePaise;
  final int tolerancePaise;
  final List<CashDenomination> denominations;
  final CashClosingStatus status;
  final String closedBy;
  final String? cashierNote;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? approvalReason;
  final DateTime createdAt;

  const CashClosingRecord({
    required this.id,
    required this.closingDate,
    required this.expectedCashPaise,
    required this.countedCashPaise,
    required this.variancePaise,
    required this.tolerancePaise,
    required this.denominations,
    required this.status,
    required this.closedBy,
    this.cashierNote,
    this.approvedBy,
    this.approvedAt,
    this.approvalReason,
    required this.createdAt,
  });

  bool get needsApproval => status == CashClosingStatus.mismatchPending;
  double get varianceRupees => variancePaise / 100.0;
  double get expectedCashRupees => expectedCashPaise / 100.0;
  double get countedCashRupees => countedCashPaise / 100.0;

  factory CashClosingRecord.fromJson(Map<String, dynamic> json) {
    final rawDenoms = json['denominations'] as List? ?? const <dynamic>[];
    return CashClosingRecord(
      id: json['id'] as String,
      closingDate: json['closingDate'] as String,
      expectedCashPaise: (json['expectedCashPaise'] as num).toInt(),
      countedCashPaise: (json['countedCashPaise'] as num).toInt(),
      variancePaise: (json['variancePaise'] as num).toInt(),
      tolerancePaise: (json['tolerancePaise'] as num).toInt(),
      denominations: rawDenoms
          .whereType<Map>()
          .map((dynamic e) =>
              CashDenomination.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      status: CashClosingStatus.parse(json['status'] as String?),
      closedBy: (json['closedBy'] as String?) ?? '',
      cashierNote: json['cashierNote'] as String?,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: (json['approvedAt'] as String?) != null
          ? DateTime.tryParse(json['approvedAt'] as String)
          : null,
      approvalReason: json['approvalReason'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class CashClosingException implements Exception {
  final int statusCode;
  final String message;
  const CashClosingException(this.statusCode, this.message);

  @override
  String toString() => 'CashClosingException($statusCode): $message';
}

class DayEndCashService {
  final ApiClient _api;

  DayEndCashService({ApiClient? apiClient})
    : _api = apiClient ?? sl<ApiClient>();

  /// GET /cash-closings/preview — expected cash for the date, server-computed.
  Future<CashClosingPreview> preview({String? date}) async {
    final response = await _api.get(
      '/cash-closings/preview',
      queryParams: <String, String>{
        'date': ?date,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw CashClosingException(
        response.statusCode,
        response.error ?? 'Failed to load expected cash preview',
      );
    }
    return CashClosingPreview.fromJson(_extractData(response.data!));
  }

  /// POST /cash-closings — record the day close.
  Future<CashClosingRecord> recordClose({
    required int countedCashPaise,
    required List<CashDenomination> denominations,
    String? cashierNote,
    String? closingDate,
    String? shiftId,
  }) async {
    final response = await _api.post(
      '/cash-closings',
      body: <String, dynamic>{
        'countedCashPaise': countedCashPaise,
        'denominations':
            denominations.map((CashDenomination d) => d.toJson()).toList(),
        if (cashierNote != null && cashierNote.isNotEmpty) 'cashierNote': cashierNote,
        'closingDate': ?closingDate,
        'shiftId': ?shiftId,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw CashClosingException(
        response.statusCode,
        response.error ?? 'Failed to record cash closing',
      );
    }
    return CashClosingRecord.fromJson(_extractData(response.data!));
  }

  /// GET /cash-closings/by-date/{date} — fetch existing close for the date.
  Future<CashClosingRecord?> getByDate(String date) async {
    final response = await _api.get('/cash-closings/by-date/$date');
    if (response.statusCode == 404) return null;
    if (!response.isSuccess || response.data == null) {
      throw CashClosingException(
        response.statusCode,
        response.error ?? 'Failed to fetch cash closing',
      );
    }
    return CashClosingRecord.fromJson(_extractData(response.data!));
  }

  /// GET /cash-closings — list closings (newest first, default 30).
  Future<List<CashClosingRecord>> list({int limit = 30}) async {
    final response = await _api.get(
      '/cash-closings',
      queryParams: <String, String>{'limit': '$limit'},
    );
    if (!response.isSuccess || response.data == null) {
      throw CashClosingException(
        response.statusCode,
        response.error ?? 'Failed to list cash closings',
      );
    }
    final payload = _extractData(response.data!);
    final raw = payload['items'] as List? ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((dynamic e) =>
            CashClosingRecord.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// POST /cash-closings/{date}/approve — owner-approve a variance.
  Future<CashClosingRecord> approve({
    required String date,
    required String reason,
  }) async {
    final response = await _api.post(
      '/cash-closings/$date/approve',
      body: <String, dynamic>{'reason': reason},
    );
    if (!response.isSuccess || response.data == null) {
      throw CashClosingException(
        response.statusCode,
        response.error ?? 'Failed to approve cash closing',
      );
    }
    return CashClosingRecord.fromJson(_extractData(response.data!));
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return body;
  }
}

/// Standard Indian cash denominations (descending order). Used to seed the
/// denomination grid in the day-end close UI. Values are in paise.
const List<int> kIndianCashDenominationsPaise = <int>[
  200000, // ₹2000
  50000,  // ₹500
  20000,  // ₹200
  10000,  // ₹100
  5000,   // ₹50
  2000,   // ₹20
  1000,   // ₹10
  500,    // ₹5
  200,    // ₹2
  100,    // ₹1
];
