import 'package:dukanx/core/compat/firestore_compat.dart';

/// Shift status enum
enum ShiftStatus { open, closed }

/// Extension for display properties
extension ShiftStatusExtension on ShiftStatus {
  String get displayName {
    switch (this) {
      case ShiftStatus.open:
        return 'Open';
      case ShiftStatus.closed:
        return 'Closed';
    }
  }

  bool get isOpen => this == ShiftStatus.open;
  bool get isClosed => this == ShiftStatus.closed;
}

/// Payment breakup for shift summary
class PaymentBreakup {
  final double cash;
  final double upi;
  final double card;
  final double credit;

  const PaymentBreakup({
    this.cash = 0.0,
    this.upi = 0.0,
    this.card = 0.0,
    this.credit = 0.0,
  });

  double get total => cash + upi + card + credit;

  PaymentBreakup copyWith({
    double? cash,
    double? upi,
    double? card,
    double? credit,
  }) {
    return PaymentBreakup(
      cash: cash ?? this.cash,
      upi: upi ?? this.upi,
      card: card ?? this.card,
      credit: credit ?? this.credit,
    );
  }

  PaymentBreakup add(PaymentBreakup other) {
    return PaymentBreakup(
      cash: cash + other.cash,
      upi: upi + other.upi,
      card: card + other.card,
      credit: credit + other.credit,
    );
  }

  Map<String, dynamic> toMap() => {
    'cash': cash,
    'upi': upi,
    'card': card,
    'credit': credit,
  };

  factory PaymentBreakup.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PaymentBreakup();
    return PaymentBreakup(
      cash: (map['cash'] as num?)?.toDouble() ?? 0.0,
      upi: (map['upi'] as num?)?.toDouble() ?? 0.0,
      card: (map['card'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Shift entity for petrol pump shift management
/// Tracks sales, payments, and employee assignments per shift
class Shift {
  final String shiftId;
  final String shiftName; // Morning / Evening / Night
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> assignedEmployeeIds;
  final double totalSaleAmount;
  final double totalLitresSold;
  final PaymentBreakup paymentBreakup;
  final ShiftStatus status;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? closedBy; // Employee ID who closed the shift
  final String? notes;

  Shift({
    required this.shiftId,
    required this.shiftName,
    required this.startTime,
    this.endTime,
    this.assignedEmployeeIds = const [],
    this.totalSaleAmount = 0.0,
    this.totalLitresSold = 0.0,
    this.paymentBreakup = const PaymentBreakup(),
    this.status = ShiftStatus.open,
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.closedBy,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Check if shift can be closed
  bool get canClose => status.isOpen;

  /// Duration of the shift
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Human-readable duration
  String get durationString {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Shift copyWith({
    String? shiftId,
    String? shiftName,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? assignedEmployeeIds,
    double? totalSaleAmount,
    double? totalLitresSold,
    PaymentBreakup? paymentBreakup,
    ShiftStatus? status,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? closedBy,
    String? notes,
  }) {
    return Shift(
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      totalSaleAmount: totalSaleAmount ?? this.totalSaleAmount,
      totalLitresSold: totalLitresSold ?? this.totalLitresSold,
      paymentBreakup: paymentBreakup ?? this.paymentBreakup,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      closedBy: closedBy ?? this.closedBy,
      notes: notes ?? this.notes,
    );
  }

  /// Close the shift with final totals
  Shift close({
    required double totalSaleAmount,
    required double totalLitresSold,
    required PaymentBreakup paymentBreakup,
    String? closedBy,
    String? notes,
  }) {
    return copyWith(
      endTime: DateTime.now(),
      totalSaleAmount: totalSaleAmount,
      totalLitresSold: totalLitresSold,
      paymentBreakup: paymentBreakup,
      status: ShiftStatus.closed,
      closedBy: closedBy,
      notes: notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'shiftId': shiftId,
    'shiftName': shiftName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'assignedEmployeeIds': assignedEmployeeIds,
    'totalSaleAmount': totalSaleAmount,
    'totalLitresSold': totalLitresSold,
    'paymentBreakup': paymentBreakup.toMap(),
    'status': status.name,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'closedBy': closedBy,
    'notes': notes,
  };

  factory Shift.fromMap(String id, Map<String, dynamic> map) {
    return Shift(
      shiftId: id,
      shiftName: map['shiftName'] as String? ?? 'Shift',
      startTime: _parseDateTime(map['startTime']),
      endTime: map['endTime'] != null ? _parseDateTime(map['endTime']) : null,
      assignedEmployeeIds:
          (map['assignedEmployeeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalSaleAmount: (map['totalSaleAmount'] as num?)?.toDouble() ?? 0.0,
      totalLitresSold: (map['totalLitresSold'] as num?)?.toDouble() ?? 0.0,
      paymentBreakup: PaymentBreakup.fromMap(
        map['paymentBreakup'] as Map<String, dynamic>?,
      ),
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ShiftStatus.open,
      ),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      closedBy: map['closedBy'] as String?,
      notes: map['notes'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Default shift names
  static const List<String> defaultShiftNames = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];
}
