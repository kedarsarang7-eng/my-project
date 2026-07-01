// Gold Scheme / Chit Fund Model - Monthly Gold Saving
// Feature 4: Gold Scheme/Chit Management

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'jewellery_product_model.dart';
import 'package:hive/hive.dart';

part 'gold_scheme_model.freezed.dart';
part 'gold_scheme_model.g.dart';

/// Gold Scheme enrollment status
enum SchemeStatus {
  active,       // Customer is paying regularly
  paused,       // Temporarily paused
  completed,    // All payments done, ready for redemption
  redeemed,     // Gold purchased/payout done
  defaulted,    // Too many missed payments
  cancelled,    // Cancelled by customer or admin
}

extension SchemeStatusExtension on SchemeStatus {
  String get displayName {
    switch (this) {
      case SchemeStatus.active:
        return 'Active';
      case SchemeStatus.paused:
        return 'Paused';
      case SchemeStatus.completed:
        return 'Completed';
      case SchemeStatus.redeemed:
        return 'Redeemed';
      case SchemeStatus.defaulted:
        return 'Defaulted';
      case SchemeStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case SchemeStatus.active:
        return Colors.green;
      case SchemeStatus.paused:
        return Colors.orange;
      case SchemeStatus.completed:
        return Colors.blue;
      case SchemeStatus.redeemed:
        return Colors.purple;
      case SchemeStatus.defaulted:
        return Colors.red;
      case SchemeStatus.cancelled:
        return Colors.grey;
    }
  }
}

/// Scheme payment frequency
enum PaymentFrequency {
  monthly,
  weekly,
  daily,
}

extension PaymentFrequencyExtension on PaymentFrequency {
  String get displayName {
    switch (this) {
      case PaymentFrequency.monthly:
        return 'Monthly';
      case PaymentFrequency.weekly:
        return 'Weekly';
      case PaymentFrequency.daily:
        return 'Daily';
    }
  }

  int get daysInterval {
    switch (this) {
      case PaymentFrequency.monthly:
        return 30;
      case PaymentFrequency.weekly:
        return 7;
      case PaymentFrequency.daily:
        return 1;
    }
  }
}

/// Scheme redemption type
enum RedemptionType {
  goldJewellery,  // Buy jewellery with accumulated amount
  goldCoin,       // Buy gold coins/bars
  cashPayout,     // Take cash (usually minus some charges)
  bankTransfer,   // Transfer to bank account
}

extension RedemptionTypeExtension on RedemptionType {
  String get displayName {
    switch (this) {
      case RedemptionType.goldJewellery:
        return 'Gold Jewellery';
      case RedemptionType.goldCoin:
        return 'Gold Coin/Bar';
      case RedemptionType.cashPayout:
        return 'Cash Payout';
      case RedemptionType.bankTransfer:
        return 'Bank Transfer';
    }
  }
}

/// Payment record for a scheme installment
@freezed
abstract class SchemePayment with _$SchemePayment {
  @HiveType(typeId: 66)
  const factory SchemePayment({
    @HiveField(0) required String id,
    @HiveField(1) required int installmentNumber,
    @HiveField(2) required int amountPaisa,
    @HiveField(3) required DateTime dueDate,
    @HiveField(4) DateTime? paidDate,
    @HiveField(5) int? paidAmountPaisa,
    @HiveField(6) @Default(false) bool isPaid,
    @HiveField(7) @Default(false) bool isLate,
    @HiveField(8) int? lateFeePaisa,
    @HiveField(9) String? paymentMode, // Cash, UPI, Card, etc.
    @HiveField(10) String? transactionId,
    @HiveField(11) String? notes,
    @HiveField(12) String? receivedBy,
    @HiveField(13) List<String>? reminderSentDates,
  }) = _SchemePayment;

  const SchemePayment._();

  factory SchemePayment.fromJson(Map<String, dynamic> json) =>
      _$SchemePaymentFromJson(json);

  double get displayAmount => amountPaisa / 100;
  double? get displayPaidAmount => paidAmountPaisa != null ? paidAmountPaisa! / 100 : null;
  double? get displayLateFee => lateFeePaisa != null ? lateFeePaisa! / 100 : null;

  /// Days overdue
  int? get daysOverdue {
    if (isPaid) return null;
    if (dueDate.isAfter(DateTime.now())) return null;
    return DateTime.now().difference(dueDate).inDays;
  }
}

/// Gold weight record (for gold-linked schemes)
@freezed
abstract class GoldWeightRecord with _$GoldWeightRecord {
  @HiveType(typeId: 67)
  const factory GoldWeightRecord({
    @HiveField(0) required DateTime date,
    @HiveField(1) required double goldRatePerGramPaisa,
    @HiveField(2) required double goldWeightGrams,
    @HiveField(3) required int amountPaisa,
    @HiveField(4) String? notes,
  }) = _GoldWeightRecord;

  const GoldWeightRecord._();

  factory GoldWeightRecord.fromJson(Map<String, dynamic> json) =>
      _$GoldWeightRecordFromJson(json);

  double get displayGoldRate => goldRatePerGramPaisa / 100;
  double get displayAmount => amountPaisa / 100;
}

/// Redemption record
@freezed
abstract class SchemeRedemption with _$SchemeRedemption {
  @HiveType(typeId: 68)
  const factory SchemeRedemption({
    @HiveField(0) required String id,
    @HiveField(1) required RedemptionType type,
    @HiveField(2) required DateTime redemptionDate,
    @HiveField(3) required int totalAmountPaisa,
    @HiveField(4) int? bonusAmountPaisa,
    @HiveField(5) int? discountAmountPaisa,
    @HiveField(6) int? finalAmountPaisa,
    
    // For gold redemption
    @HiveField(7) double? goldWeightGrams,
    @HiveField(8) double? goldRateAtRedemptionPaisa,
    @HiveField(9) String? purity,
    
    // For jewellery redemption
    @HiveField(10) String? productId,
    @HiveField(11) String? productName,
    @HiveField(12) String? invoiceId,
    
    // For cash/bank redemption
    @HiveField(13) String? bankAccountNumber,
    @HiveField(14) String? bankIfsc,
    @HiveField(15) String? upiId,
    @HiveField(16) DateTime? payoutDate,
    
    @HiveField(17) String? notes,
    @HiveField(18) String? processedBy,
  }) = _SchemeRedemption;

  const SchemeRedemption._();

  factory SchemeRedemption.fromJson(Map<String, dynamic> json) =>
      _$SchemeRedemptionFromJson(json);

  double get displayTotalAmount => totalAmountPaisa / 100;
  double? get displayBonusAmount => bonusAmountPaisa != null ? bonusAmountPaisa! / 100 : null;
  double? get displayDiscountAmount => discountAmountPaisa != null ? discountAmountPaisa! / 100 : null;
  double? get displayFinalAmount => finalAmountPaisa != null ? finalAmountPaisa! / 100 : null;
  double? get displayGoldRate => goldRateAtRedemptionPaisa != null ? goldRateAtRedemptionPaisa! / 100 : null;
}

/// Gold Scheme / Chit Fund - Main entity
@freezed
abstract class GoldScheme with _$GoldScheme {
  @HiveType(typeId: 69)
  const factory GoldScheme({
    // Core identifiers
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String schemeNumber, // e.g., GS-2024-0001
    
    // Customer info
    @HiveField(3) required String customerId,
    @HiveField(4) required String customerName,
    @HiveField(5) String? customerPhone,
    @HiveField(6) String? customerEmail,
    @HiveField(7) String? customerAddress,
    
    // Scheme configuration
    @HiveField(8) required String schemeName,
    @HiveField(9) String? schemeDescription,
    @HiveField(10) required int installmentAmountPaisa,
    @HiveField(11) required int totalInstallments,
    @HiveField(12) @Default(PaymentFrequency.monthly) PaymentFrequency frequency,
    @HiveField(13) int? minimumInstallmentsForRedemption,
    
    // Bonus/Vendor contribution
    @HiveField(14) int? vendorBonusPaisa, // Jeweller contributes this amount
    @HiveField(15) double? bonusPercentage, // Or as percentage
    @HiveField(16) String? bonusDescription, // "Pay for 11 months, get 12th free"
    
    // Gold-linked scheme (optional)
    @HiveField(17) @Default(false) bool isGoldLinked,
    @HiveField(18) MetalType? linkedMetalType,
    @HiveField(19) List<GoldWeightRecord>? goldWeightHistory,
    
    // Current status
    @HiveField(20) @Default(SchemeStatus.active) SchemeStatus status,
    @HiveField(21) required DateTime startDate,
    @HiveField(22) DateTime? endDate,
    @HiveField(23) DateTime? promisedRedemptionDate,
    
    // Payments
    @HiveField(24) required List<SchemePayment> payments,
    @HiveField(25) @Default(0) int completedInstallments,
    @HiveField(26) @Default(0) int missedInstallments,
    @HiveField(27) @Default(0) int lateInstallments,
    
    // Financial summary
    @HiveField(28) @Default(0) int totalPaidPaisa,
    @HiveField(29) @Default(0) int totalLateFeesPaisa,
    @HiveField(30) int? accumulatedGoldWeightGrams, // For gold-linked schemes
    
    // Redemption
    @HiveField(31) SchemeRedemption? redemption,
    @HiveField(32) RedemptionType? plannedRedemptionType,
    
    // Defaults handling
    @HiveField(33) int? defaultAfterMissedInstallments,
    @HiveField(34) int? foreclosureChargePercent,
    @HiveField(35) DateTime? defaultedDate,
    @HiveField(36) String? defaultReason,
    
    // Cancellation
    @HiveField(37) DateTime? cancelledDate,
    @HiveField(38) String? cancellationReason,
    @HiveField(39) int? cancellationChargesPaisa,
    @HiveField(40) int? refundAmountPaisa,
    
    // Referral
    @HiveField(41) String? referredByCustomerId,
    @HiveField(42) String? referralCode,
    
    // Metadata
    @HiveField(43) required DateTime createdAt,
    @HiveField(44) required String createdBy,
    @HiveField(45) required DateTime updatedAt,
    @HiveField(46) required String updatedBy,
    
    // Sync
    @HiveField(47) @Default(true) bool synced,
    @HiveField(48) DateTime? lastSyncedAt,
    @HiveField(49) String? pendingOperation,
  }) = _GoldScheme;

  const GoldScheme._();

  factory GoldScheme.fromJson(Map<String, dynamic> json) =>
      _$GoldSchemeFromJson(json);

  // Display getters
  double get displayInstallmentAmount => installmentAmountPaisa / 100;
  double? get displayVendorBonus => vendorBonusPaisa != null ? vendorBonusPaisa! / 100 : null;
  double get displayTotalPaid => totalPaidPaisa / 100;
  double? get displayAccumulatedGoldWeight => accumulatedGoldWeightGrams != null ? accumulatedGoldWeightGrams! / 1000 : null; // Convert mg to g if stored in mg
  
  /// Calculate total scheme value (customer payments + bonus)
  int get totalSchemeValuePaisa {
    int total = totalPaidPaisa;
    if (vendorBonusPaisa != null) {
      total += vendorBonusPaisa!;
    }
    return total;
  }
  double get displayTotalSchemeValue => totalSchemeValuePaisa / 100;

  /// Calculate remaining installments
  int get remainingInstallments => totalInstallments - completedInstallments;

  /// Check if eligible for redemption
  bool get canRedeem {
    if (status != SchemeStatus.active && status != SchemeStatus.completed) return false;
    if (minimumInstallmentsForRedemption == null) return true;
    return completedInstallments >= minimumInstallmentsForRedemption!;
  }

  /// Get next payment due
  SchemePayment? get nextPaymentDue {
    try {
      return payments.firstWhere((p) => !p.isPaid);
    } catch (e) {
      return null;
    }
  }

  /// Days until next payment
  int? get daysUntilNextPayment {
    final next = nextPaymentDue;
    if (next == null) return null;
    return next.dueDate.difference(DateTime.now()).inDays;
  }

  /// Check if any payments are overdue
  bool get hasOverduePayments {
    return payments.any((p) => !p.isPaid && p.dueDate.isBefore(DateTime.now()));
  }

  /// Get overdue payments count
  int get overduePaymentsCount {
    return payments.where((p) => !p.isPaid && p.dueDate.isBefore(DateTime.now())).length;
  }

  /// Progress percentage
  double get progressPercent {
    return (completedInstallments / totalInstallments) * 100;
  }

  /// Estimate completion date
  DateTime? get estimatedCompletionDate {
    if (status == SchemeStatus.completed || status == SchemeStatus.redeemed) {
      return endDate;
    }
    final remaining = remainingInstallments;
    if (remaining <= 0) return null;
    return DateTime.now().add(Duration(days: remaining * frequency.daysInterval));
  }
}

/// Scheme template for creating new schemes
@freezed
abstract class SchemeTemplate with _$SchemeTemplate {
  @HiveType(typeId: 70)
  const factory SchemeTemplate({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) String? description,
    @HiveField(3) required int installmentAmountPaisa,
    @HiveField(4) required int totalInstallments,
    @HiveField(5) @Default(PaymentFrequency.monthly) PaymentFrequency frequency,
    @HiveField(6) int? vendorBonusPaisa,
    @HiveField(7) double? bonusPercentage,
    @HiveField(8) String? bonusDescription,
    @HiveField(9) int? minimumInstallmentsForRedemption,
    @HiveField(10) @Default(false) bool isGoldLinked,
    @HiveField(11) MetalType? linkedMetalType,
    @HiveField(12) int? defaultAfterMissedInstallments,
    @HiveField(13) int? foreclosureChargePercent,
    @HiveField(14) @Default(true) bool isActive,
  }) = _SchemeTemplate;

  const SchemeTemplate._();

  factory SchemeTemplate.fromJson(Map<String, dynamic> json) =>
      _$SchemeTemplateFromJson(json);

  double get displayInstallmentAmount => installmentAmountPaisa / 100;
  double? get displayVendorBonus => vendorBonusPaisa != null ? vendorBonusPaisa! / 100 : null;
}

/// Statistics for gold schemes
@freezed
abstract class GoldSchemeStatistics with _$GoldSchemeStatistics {
  const factory GoldSchemeStatistics({
    @Default(0) int totalSchemes,
    @Default(0) int activeSchemes,
    @Default(0) int completedSchemes,
    @Default(0) int redeemedSchemes,
    @Default(0) int defaultedSchemes,
    @Default(0) int totalCustomers,
    @Default(0) int totalPaidPaisa,
    @Default(0) int totalBonusPaisa,
    @Default(0) int totalOutstandingPaisa,
    @Default(0) int totalOverduePaisa,
    @Default(0.0) double averageSchemeDuration,
    @Default(0) int schemesDueThisMonth,
    @Default(0) int schemesOverdue,
  }) = _GoldSchemeStatistics;

  const GoldSchemeStatistics._();

  factory GoldSchemeStatistics.fromJson(Map<String, dynamic> json) =>
      _$GoldSchemeStatisticsFromJson(json);

  double get displayTotalPaid => totalPaidPaisa / 100;
  double get displayTotalBonus => totalBonusPaisa / 100;
  double get displayTotalOutstanding => totalOutstandingPaisa / 100;
  double get displayTotalOverdue => totalOverduePaisa / 100;
}

/// Request models
class CreateGoldSchemeRequest {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? templateId;
  final String? schemeName;
  final int installmentAmountPaisa;
  final int totalInstallments;
  final PaymentFrequency frequency;
  final int? vendorBonusPaisa;
  final double? bonusPercentage;
  final String? bonusDescription;
  final int? minimumInstallmentsForRedemption;
  final bool isGoldLinked;
  final MetalType? linkedMetalType;
  final RedemptionType? plannedRedemptionType;
  final DateTime? startDate;
  final String? referredByCustomerId;
  final String? referralCode;

  CreateGoldSchemeRequest({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.templateId,
    this.schemeName,
    required this.installmentAmountPaisa,
    required this.totalInstallments,
    this.frequency = PaymentFrequency.monthly,
    this.vendorBonusPaisa,
    this.bonusPercentage,
    this.bonusDescription,
    this.minimumInstallmentsForRedemption,
    this.isGoldLinked = false,
    this.linkedMetalType,
    this.plannedRedemptionType,
    this.startDate,
    this.referredByCustomerId,
    this.referralCode,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerEmail': customerEmail,
    'customerAddress': customerAddress,
    'templateId': templateId,
    'schemeName': schemeName,
    'installmentAmountPaisa': installmentAmountPaisa,
    'totalInstallments': totalInstallments,
    'frequency': frequency.name,
    'vendorBonusPaisa': vendorBonusPaisa,
    'bonusPercentage': bonusPercentage,
    'bonusDescription': bonusDescription,
    'minimumInstallmentsForRedemption': minimumInstallmentsForRedemption,
    'isGoldLinked': isGoldLinked,
    'linkedMetalType': linkedMetalType?.name,
    'plannedRedemptionType': plannedRedemptionType?.name,
    'startDate': startDate?.toIso8601String(),
    'referredByCustomerId': referredByCustomerId,
    'referralCode': referralCode,
  };
}

class RecordSchemePaymentRequest {
  final String schemeId;
  final int installmentNumber;
  final int paidAmountPaisa;
  final DateTime? paidDate;
  final String? paymentMode;
  final String? transactionId;
  final String? notes;

  RecordSchemePaymentRequest({
    required this.schemeId,
    required this.installmentNumber,
    required this.paidAmountPaisa,
    this.paidDate,
    this.paymentMode,
    this.transactionId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'schemeId': schemeId,
    'installmentNumber': installmentNumber,
    'paidAmountPaisa': paidAmountPaisa,
    'paidDate': paidDate?.toIso8601String(),
    'paymentMode': paymentMode,
    'transactionId': transactionId,
    'notes': notes,
  };
}

class RedeemSchemeRequest {
  final String schemeId;
  final RedemptionType redemptionType;
  final int? finalAmountPaisa;
  
  // For gold redemption
  final double? goldWeightGrams;
  final double? goldRatePaisa;
  final String? purity;
  
  // For jewellery
  final String? productId;
  final String? productName;
  
  // For cash/bank
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? upiId;
  
  final String? notes;

  RedeemSchemeRequest({
    required this.schemeId,
    required this.redemptionType,
    this.finalAmountPaisa,
    this.goldWeightGrams,
    this.goldRatePaisa,
    this.purity,
    this.productId,
    this.productName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.upiId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'schemeId': schemeId,
    'redemptionType': redemptionType.name,
    'finalAmountPaisa': finalAmountPaisa,
    'goldWeightGrams': goldWeightGrams,
    'goldRatePaisa': goldRatePaisa,
    'purity': purity,
    'productId': productId,
    'productName': productName,
    'bankAccountNumber': bankAccountNumber,
    'bankIfsc': bankIfsc,
    'upiId': upiId,
    'notes': notes,
  };
}

/// Preset scheme templates
class SchemeTemplates {
  static SchemeTemplate standardMonthly11Plus1() {
    return SchemeTemplate(
      id: 'template_11plus1',
      name: '11+1 Monthly Scheme',
      description: 'Pay for 11 months, get 1 month free from jeweller. Popular scheme.',
      installmentAmountPaisa: 0, // Will be set per customer
      totalInstallments: 12,
      frequency: PaymentFrequency.monthly,
      bonusPercentage: 9.09, // 1 out of 11 is ~9.09%
      bonusDescription: 'Pay for 11 months, get 12th month free',
      minimumInstallmentsForRedemption: 11,
      isGoldLinked: false,
    );
  }

  static SchemeTemplate goldAccumulation() {
    return SchemeTemplate(
      id: 'template_gold_accumulation',
      name: 'Gold Accumulation Plan',
      description: 'Monthly payments converted to gold weight at daily rates',
      installmentAmountPaisa: 0,
      totalInstallments: 12,
      frequency: PaymentFrequency.monthly,
      minimumInstallmentsForRedemption: 6,
      isGoldLinked: true,
      linkedMetalType: MetalType.gold22k,
    );
  }

  static SchemeTemplate flexibleDaily() {
    return SchemeTemplate(
      id: 'template_flexible_daily',
      name: 'Flexible Daily Savings',
      description: 'Save daily any amount, redeem when target reached',
      installmentAmountPaisa: 0,
      totalInstallments: 365,
      frequency: PaymentFrequency.daily,
      minimumInstallmentsForRedemption: 300,
      isGoldLinked: false,
    );
  }
}
