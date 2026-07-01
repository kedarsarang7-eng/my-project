// ============================================================================
// CASH CLOSING SERVICE
// ============================================================================
// Daily cash reconciliation service for fraud prevention.
// Compares expected vs actual cash and handles variances.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import 'owner_pin_service.dart';
import 'fraud_detection_service.dart';
import '../../repository/audit_repository.dart';

/// Cash Closing Model
class CashClosing {
  final String id;
  final String businessId;
  final DateTime closingDate;
  final double expectedCash;
  final double actualCash;
  final double variance;
  final String closedBy;
  final CashClosingStatus status;
  final String? approvedBy;
  final String? approvalReason;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const CashClosing({
    required this.id,
    required this.businessId,
    required this.closingDate,
    required this.expectedCash,
    required this.actualCash,
    required this.variance,
    required this.closedBy,
    required this.status,
    this.approvedBy,
    this.approvalReason,
    required this.createdAt,
    this.approvedAt,
  });

  factory CashClosing.fromMap(String id, Map<String, dynamic> map) {
    return CashClosing(
      id: id,
      businessId: map['businessId'] as String,
      closingDate: _parseDate(map['closingDate']) ?? DateTime.now(),
      expectedCash: (map['expectedCash'] as num?)?.toDouble() ?? 0.0,
      actualCash: (map['actualCash'] as num?)?.toDouble() ?? 0.0,
      variance: (map['variance'] as num?)?.toDouble() ?? 0.0,
      closedBy: map['closedBy'] as String,
      status: CashClosingStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => CashClosingStatus.matched,
      ),
      approvedBy: map['approvedBy'] as String?,
      approvalReason: map['approvalReason'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      approvedAt: _parseDate(map['approvedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'closingDate': closingDate.toIso8601String(),
    'expectedCash': expectedCash,
    'actualCash': actualCash,
    'variance': variance,
    'closedBy': closedBy,
    'status': status.name,
    'approvedBy': approvedBy,
    'approvalReason': approvalReason,
    'createdAt': createdAt.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
  };

  Map<String, dynamic> toFirestore() => {
    'businessId': businessId,
    'closingDate': Timestamp.fromDate(closingDate),
    'expectedCash': expectedCash,
    'actualCash': actualCash,
    'variance': variance,
    'closedBy': closedBy,
    'status': status.name,
    'approvedBy': approvedBy,
    'approvalReason': approvalReason,
    'createdAt': Timestamp.fromDate(createdAt),
    'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
  };

  CashClosing copyWith({
    CashClosingStatus? status,
    String? approvedBy,
    String? approvalReason,
    DateTime? approvedAt,
  }) {
    return CashClosing(
      id: id,
      businessId: businessId,
      closingDate: closingDate,
      expectedCash: expectedCash,
      actualCash: actualCash,
      variance: variance,
      closedBy: closedBy,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvalReason: approvalReason ?? this.approvalReason,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Cash closing status
enum CashClosingStatus {
  /// Cash matched expected amount
  matched,

  /// Mismatch detected, pending approval
  mismatchPending,

  /// Mismatch approved by owner
  mismatchApproved,
}

/// Cash Closing Service - Daily cash reconciliation.
///
/// Features:
/// - Record daily cash closing
/// - Detect and flag variances
/// - Block billing until mismatch resolved
/// - Integration with fraud alerts
class CashClosingService {
  final FirebaseFirestore _firestore;
  final OwnerPinService _pinService;
  final FraudDetectionService _fraudService;
  final AuditRepository _auditRepository;

  /// In-memory cache of today's closing status by business
  final Map<String, CashClosing?> _todayClosingCache = {};

  CashClosingService({
    FirebaseFirestore? firestore,
    required OwnerPinService pinService,
    required FraudDetectionService fraudService,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _pinService = pinService,
       _fraudService = fraudService,
       _auditRepository = auditRepository;

  /// Record daily cash closing
  Future<CashClosing> recordDayClose({
    required String businessId,
    required double expectedCash,
    required double actualCash,
    required String closedBy,
  }) async {
    final now = DateTime.now();
    final closingDate = DateTime(now.year, now.month, now.day);
    final variance = expectedCash - actualCash;

    // Check if already closed today
    final existing = await getTodayClosing(businessId);
    if (existing != null) {
      throw CashClosingException(
        'Day already closed for ${closingDate.toIso8601String().split('T')[0]}',
      );
    }

    // Determine status based on variance
    final settings = await _pinService.getSecuritySettings(businessId);
    final tolerance = settings?.cashToleranceLimit ?? 100.0;

    final status = variance.abs() <= tolerance
        ? CashClosingStatus.matched
        : CashClosingStatus.mismatchPending;

    final closing = CashClosing(
      id: '${businessId}_${closingDate.millisecondsSinceEpoch}',
      businessId: businessId,
      closingDate: closingDate,
      expectedCash: expectedCash,
      actualCash: actualCash,
      variance: variance,
      closedBy: closedBy,
      status: status,
      createdAt: now,
    );

    // Save to Firestore
    await _firestore
        .collection('cash_closings')
        .doc(closing.id)
        .set(closing.toFirestore());

    // Cache
    _todayClosingCache[businessId] = closing;

    // Create fraud alert if mismatch
    if (status == CashClosingStatus.mismatchPending) {
      await _fraudService.checkCashVariance(
        businessId: businessId,
        userId: closedBy,
        expectedCash: expectedCash,
        actualCash: actualCash,
      );
    }

    // Audit log
    await _auditRepository.logAction(
      userId: closedBy,
      targetTableName: 'cash_closings',
      recordId: closing.id,
      action: 'CREATE',
      newValueJson: '${closing.toMap()}',
    );

    debugPrint('CashClosingService: Day closed with ${status.name}');
    return closing;
  }

  /// Approve cash mismatch (requires PIN)
  Future<CashClosing> approveMismatch({
    required String closingId,
    required String approvedBy,
    required String pin,
    String? reason,
  }) async {
    // Get closing
    final doc = await _firestore
        .collection('cash_closings')
        .doc(closingId)
        .get();
    if (!doc.exists) {
      throw CashClosingException('Closing not found');
    }

    final closing = CashClosing.fromMap(doc.id, doc.data()!);

    if (closing.status != CashClosingStatus.mismatchPending) {
      throw CashClosingException('Closing is not pending approval');
    }

    // Verify PIN
    final isValid = await _pinService.verifyPin(
      businessId: closing.businessId,
      pin: pin,
    );

    if (!isValid) {
      throw CashClosingException('Invalid PIN');
    }

    // Update status
    final updated = closing.copyWith(
      status: CashClosingStatus.mismatchApproved,
      approvedBy: approvedBy,
      approvalReason: reason ?? 'Approved by owner',
      approvedAt: DateTime.now(),
    );

    await _firestore.collection('cash_closings').doc(closingId).update({
      'status': updated.status.name,
      'approvedBy': updated.approvedBy,
      'approvalReason': updated.approvalReason,
      'approvedAt': Timestamp.fromDate(updated.approvedAt!),
    });

    // Update cache
    if (_todayClosingCache[closing.businessId]?.id == closingId) {
      _todayClosingCache[closing.businessId] = updated;
    }

    // Audit log
    await _auditRepository.logAction(
      userId: approvedBy,
      targetTableName: 'cash_closings',
      recordId: closingId,
      action: 'APPROVE',
      oldValueJson: '{"status": "${closing.status.name}"}',
      newValueJson: '{"status": "${updated.status.name}", "reason": "$reason"}',
    );

    return updated;
  }

  /// Check if day closing is pending for previous day
  Future<bool> isDayClosePending(String businessId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayDate = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
    );

    final closingId = '${businessId}_${yesterdayDate.millisecondsSinceEpoch}';
    final doc = await _firestore
        .collection('cash_closings')
        .doc(closingId)
        .get();

    return !doc.exists;
  }

  /// Check if there's an unresolved mismatch
  Future<bool> hasUnresolvedMismatch(String businessId) async {
    final query = await _firestore
        .collection('cash_closings')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: CashClosingStatus.mismatchPending.name)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Get today's closing (if exists)
  Future<CashClosing?> getTodayClosing(String businessId) async {
    // Check cache
    if (_todayClosingCache.containsKey(businessId)) {
      return _todayClosingCache[businessId];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final closingId = '${businessId}_${today.millisecondsSinceEpoch}';

    final doc = await _firestore
        .collection('cash_closings')
        .doc(closingId)
        .get();

    if (!doc.exists) {
      _todayClosingCache[businessId] = null;
      return null;
    }

    final closing = CashClosing.fromMap(doc.id, doc.data()!);
    _todayClosingCache[businessId] = closing;
    return closing;
  }

  /// Get closing history
  Future<List<CashClosing>> getClosingHistory({
    required String businessId,
    int limit = 30,
  }) async {
    final query = await _firestore
        .collection('cash_closings')
        .where('businessId', isEqualTo: businessId)
        .orderBy('closingDate', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => CashClosing.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Calculate expected cash from today's transactions
  Future<double> calculateExpectedCash({
    required String businessId,
    required DateTime date,
    required double openingCash,
  }) async {
    // This would query bills and payments for the day
    // For now, return opening cash (to be implemented with BillsRepository)
    debugPrint(
      'CashClosingService: calculateExpectedCash - to be implemented with billing data',
    );
    return openingCash;
  }

  /// Clear cache
  void clearCache() {
    _todayClosingCache.clear();
  }
}

/// Exception for cash closing errors
class CashClosingException implements Exception {
  final String message;
  CashClosingException(this.message);

  @override
  String toString() => 'CashClosingException: $message';
}
