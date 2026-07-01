// Jewellery Repair Model - Service & Repair Tracking
// Feature 3: Repair/Service Module

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'jewellery_repair_model.freezed.dart';
part 'jewellery_repair_model.g.dart';

/// Repair job status
enum RepairStatus {
  pending,        // Job received, waiting for assessment
  assessed,       // Damage assessed, quote prepared
  approved,       // Customer approved the quote
  inProgress,     // Repair work ongoing
  qualityCheck,   // Quality check before delivery
  ready,          // Ready for pickup
  delivered,      // Delivered to customer
  cancelled,      // Cancelled
  returned,       // Returned for re-work
}

extension RepairStatusExtension on RepairStatus {
  String get displayName {
    switch (this) {
      case RepairStatus.pending:
        return 'Pending';
      case RepairStatus.assessed:
        return 'Assessed';
      case RepairStatus.approved:
        return 'Approved';
      case RepairStatus.inProgress:
        return 'In Progress';
      case RepairStatus.qualityCheck:
        return 'Quality Check';
      case RepairStatus.ready:
        return 'Ready';
      case RepairStatus.delivered:
        return 'Delivered';
      case RepairStatus.cancelled:
        return 'Cancelled';
      case RepairStatus.returned:
        return 'Returned';
    }
  }

  Color get color {
    switch (this) {
      case RepairStatus.pending:
        return Colors.orange;
      case RepairStatus.assessed:
        return Colors.blue;
      case RepairStatus.approved:
        return Colors.purple;
      case RepairStatus.inProgress:
        return Colors.indigo;
      case RepairStatus.qualityCheck:
        return Colors.teal;
      case RepairStatus.ready:
        return Colors.green;
      case RepairStatus.delivered:
        return Colors.green.shade700;
      case RepairStatus.cancelled:
        return Colors.red;
      case RepairStatus.returned:
        return Colors.deepOrange;
    }
  }

  bool get canEdit => [
    RepairStatus.pending,
    RepairStatus.assessed,
    RepairStatus.approved,
    RepairStatus.returned,
  ].contains(this);

  bool get isCompleted => [
    RepairStatus.delivered,
    RepairStatus.cancelled,
  ].contains(this);
}

/// Type of repair service
enum RepairType {
  polishing,          // General polishing
  cleaning,         // Deep cleaning
  resizing,         // Ring resizing
  soldering,        // Soldering broken parts
  stoneSetting,     // Setting stones
  stoneReplacement, // Replacing missing stones
  chainRepair,      // Chain/link repair
  claspReplacement, // Clasp/hook replacement
  plating,          // Re-plating (rhodium, gold)
  engraving,        // Adding/removing engraving
  restoration,      // Antique restoration
  customWork,       // Custom modifications
}

extension RepairTypeExtension on RepairType {
  String get displayName {
    switch (this) {
      case RepairType.polishing:
        return 'Polishing';
      case RepairType.cleaning:
        return 'Cleaning';
      case RepairType.resizing:
        return 'Resizing';
      case RepairType.soldering:
        return 'Soldering';
      case RepairType.stoneSetting:
        return 'Stone Setting';
      case RepairType.stoneReplacement:
        return 'Stone Replacement';
      case RepairType.chainRepair:
        return 'Chain Repair';
      case RepairType.claspReplacement:
        return 'Clasp Replacement';
      case RepairType.plating:
        return 'Plating';
      case RepairType.engraving:
        return 'Engraving';
      case RepairType.restoration:
        return 'Restoration';
      case RepairType.customWork:
        return 'Custom Work';
    }
  }

  String get description {
    switch (this) {
      case RepairType.polishing:
        return 'General polishing to restore shine';
      case RepairType.cleaning:
        return 'Deep cleaning to remove dirt and buildup';
      case RepairType.resizing:
        return 'Ring band resizing up or down';
      case RepairType.soldering:
        return 'Soldering broken or cracked parts';
      case RepairType.stoneSetting:
        return 'Setting loose stones or new stones';
      case RepairType.stoneReplacement:
        return 'Replacing missing or damaged stones';
      case RepairType.chainRepair:
        return 'Repairing broken chains or links';
      case RepairType.claspReplacement:
        return 'Replacing damaged clasps or hooks';
      case RepairType.plating:
        return 'Rhodium or gold plating';
      case RepairType.engraving:
        return 'Adding or removing engravings';
      case RepairType.restoration:
        return 'Restoring antique pieces';
      case RepairType.customWork:
        return 'Custom modifications or additions';
    }
  }
}

/// Priority level for repair job
enum RepairPriority {
  low,
  normal,
  high,
  urgent,
}

extension RepairPriorityExtension on RepairPriority {
  String get displayName {
    switch (this) {
      case RepairPriority.low:
        return 'Low';
      case RepairPriority.normal:
        return 'Normal';
      case RepairPriority.high:
        return 'High';
      case RepairPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case RepairPriority.low:
        return Colors.grey;
      case RepairPriority.normal:
        return Colors.blue;
      case RepairPriority.high:
        return Colors.orange;
      case RepairPriority.urgent:
        return Colors.red;
    }
  }
}

/// Status update record
@freezed
abstract class RepairStatusUpdate with _$RepairStatusUpdate {
  @HiveType(typeId: 62)
  const factory RepairStatusUpdate({
    @HiveField(0) required RepairStatus status,
    @HiveField(1) required DateTime timestamp,
    @HiveField(2) required String updatedBy,
    @HiveField(3) String? notes,
    @HiveField(4) List<String>? photoUrls, // Photos at this stage
  }) = _RepairStatusUpdate;

  factory RepairStatusUpdate.fromJson(Map<String, dynamic> json) =>
      _$RepairStatusUpdateFromJson(json);
}

/// Repair work item (for multi-part repairs)
@freezed
abstract class RepairWorkItem with _$RepairWorkItem {
  @HiveType(typeId: 63)
  const factory RepairWorkItem({
    @HiveField(0) required String id,
    @HiveField(1) required RepairType type,
    @HiveField(2) required String description,
    @HiveField(3) int? estimatedCostPaisa,
    @HiveField(4) int? actualCostPaisa,
    @HiveField(5) @Default(false) bool isCompleted,
    @HiveField(6) String? completedBy,
    @HiveField(7) DateTime? completedAt,
    @HiveField(8) String? notes,
  }) = _RepairWorkItem;

  const RepairWorkItem._();

  factory RepairWorkItem.fromJson(Map<String, dynamic> json) =>
      _$RepairWorkItemFromJson(json);

  double? get displayEstimatedCost => estimatedCostPaisa != null 
      ? estimatedCostPaisa! / 100 
      : null;
  double? get displayActualCost => actualCostPaisa != null 
      ? actualCostPaisa! / 100 
      : null;
}

/// Material used in repair
@freezed
abstract class RepairMaterial with _$RepairMaterial {
  @HiveType(typeId: 64)
  const factory RepairMaterial({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required double quantity,
    @HiveField(3) required String unit,
    @HiveField(4) required int costPaisa,
    @HiveField(5) String? supplier,
    @HiveField(6) String? notes,
  }) = _RepairMaterial;

  const RepairMaterial._();

  factory RepairMaterial.fromJson(Map<String, dynamic> json) =>
      _$RepairMaterialFromJson(json);

  double get displayCost => costPaisa / 100;
}

/// Jewellery Repair Job - Main entity
@freezed
abstract class JewelleryRepair with _$JewelleryRepair {
  @HiveType(typeId: 65)
  const factory JewelleryRepair({
    // Core identifiers
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String jobNumber, // Unique job number (e.g., JOB-2024-0001)
    
    // Customer info
    @HiveField(3) required String customerId,
    @HiveField(4) required String customerName,
    @HiveField(5) String? customerPhone,
    @HiveField(6) String? customerEmail,
    
    // Item details
    @HiveField(7) required String itemDescription,
    @HiveField(8) String? itemCategory, // Ring, Chain, etc.
    @HiveField(9) String? metalType, // Gold 22K, Silver, etc.
    @HiveField(10) double? weightGrams,
    @HiveField(11) String? productId, // If linked to inventory
    
    // Job details
    @HiveField(12) required List<RepairWorkItem> workItems,
    @HiveField(13) List<RepairMaterial>? materials,
    
    // Status
    @HiveField(14) @Default(RepairStatus.pending) RepairStatus status,
    @HiveField(15) @Default(RepairPriority.normal) RepairPriority priority,
    @HiveField(16) List<RepairStatusUpdate>? statusHistory,
    
    // Initial condition photos
    @HiveField(17) List<String>? conditionPhotoUrls,
    @HiveField(18) String? customerComplaint, // What customer reported
    
    // Damage assessment
    @HiveField(19) String? damageAssessment,
    @HiveField(20) String? recommendedWork,
    @HiveField(21) int? estimatedCostPaisa,
    @HiveField(22) int? estimatedDays,
    @HiveField(23) DateTime? estimatedCompletionDate,
    
    // Actual costs
    @HiveField(24) int? actualCostPaisa,
    @HiveField(25) int? materialCostPaisa,
    @HiveField(26) int? laborCostPaisa,
    @HiveField(27) int? additionalChargesPaisa,
    @HiveField(28) String? additionalChargesNote,
    
    // Advance payment
    @HiveField(29) @Default(0) int advanceReceivedPaisa,
    
    // Assigned craftsmen
    @HiveField(30) String? assignedTo,
    @HiveField(31) String? assignedToName,
    @HiveField(32) DateTime? assignedAt,
    
    // Timeline
    @HiveField(33) required DateTime receivedDate,
    @HiveField(34) DateTime? promisedDate,
    @HiveField(35) DateTime? completedDate,
    @HiveField(36) DateTime? deliveredDate,
    
    // Work tracking
    @HiveField(37) DateTime? workStartedDate,
    @HiveField(38) DateTime? workCompletedDate,
    @HiveField(39) int? actualWorkHours,
    
    // Delivery
    @HiveField(40) String? deliveredTo,
    @HiveField(41) String? deliveryNotes,
    @HiveField(42) List<String>? completionPhotoUrls,
    
    // Warranty
    @HiveField(43) @Default(0) int warrantyDays,
    @HiveField(44) DateTime? warrantyExpiryDate,
    
    // Warranty claim (if this is a re-repair)
    @HiveField(45) String? originalJobId, // If this is a warranty claim
    @HiveField(46) @Default(false) bool isWarrantyClaim,
    
    // Customer feedback
    @HiveField(47) int? customerRating, // 1-5 stars
    @HiveField(48) String? customerFeedback,
    
    // Invoice
    @HiveField(49) String? invoiceId,
    @HiveField(50) @Default(false) bool isPaid,
    
    // Metadata
    @HiveField(51) required DateTime createdAt,
    @HiveField(52) required String createdBy,
    @HiveField(53) required DateTime updatedAt,
    @HiveField(54) required String updatedBy,
    
    // Sync
    @HiveField(55) @Default(true) bool synced,
    @HiveField(56) DateTime? lastSyncedAt,
    @HiveField(57) String? pendingOperation,
  }) = _JewelleryRepair;

  const JewelleryRepair._();

  factory JewelleryRepair.fromJson(Map<String, dynamic> json) =>
      _$JewelleryRepairFromJson(json);

  // Moved from factory constructor — getters cannot be inside freezed factory params
  int get balanceDuePaisa => (actualCostPaisa ?? 0) - advanceReceivedPaisa;

  // Display getters
  double? get displayEstimatedCost => estimatedCostPaisa != null 
      ? estimatedCostPaisa! / 100 
      : null;
  double? get displayActualCost => actualCostPaisa != null 
      ? actualCostPaisa! / 100 
      : null;
  double? get displayMaterialCost => materialCostPaisa != null 
      ? materialCostPaisa! / 100 
      : null;
  double? get displayLaborCost => laborCostPaisa != null 
      ? laborCostPaisa! / 100 
      : null;
  double get displayAdvance => advanceReceivedPaisa / 100;
  double? get displayBalance => balanceDuePaisa != 0 
      ? balanceDuePaisa / 100 
      : null;

  /// Check if job is overdue
  bool get isOverdue {
    if (promisedDate == null) return false;
    if (deliveredDate != null) return false;
    return DateTime.now().isAfter(promisedDate!);
  }

  /// Calculate days remaining or overdue
  int get daysRemaining {
    if (promisedDate == null) return 0;
    if (deliveredDate != null) return 0;
    return promisedDate!.difference(DateTime.now()).inDays;
  }

  /// Get days in workshop
  int get daysInWorkshop {
    final endDate = deliveredDate ?? DateTime.now();
    return endDate.difference(receivedDate).inDays;
  }

  /// Get total material cost
  double? get totalMaterialCost {
    if (materials == null || materials!.isEmpty) return null;
    return materials!.fold<double>(0.0, (sum, m) => sum + m.displayCost);
  }
}

/// Repair statistics
@freezed
abstract class RepairStatistics with _$RepairStatistics {
  const factory RepairStatistics({
    @Default(0) int totalJobs,
    @Default(0) int pendingJobs,
    @Default(0) int inProgressJobs,
    @Default(0) int completedJobs,
    @Default(0) int deliveredJobs,
    @Default(0) int overdueJobs,
    @Default(0) int warrantyClaims,
    @Default(0) double averageRepairDays,
    @Default(0) int totalRevenuePaisa,
    @Default(0) int totalMaterialCostPaisa,
    @Default(0) int totalLaborCostPaisa,
  }) = _RepairStatistics;

  const RepairStatistics._();

  factory RepairStatistics.fromJson(Map<String, dynamic> json) =>
      _$RepairStatisticsFromJson(json);

  double get displayTotalRevenue => totalRevenuePaisa / 100;
  double get displayTotalMaterialCost => totalMaterialCostPaisa / 100;
  double get displayTotalLaborCost => totalLaborCostPaisa / 100;
  double get displayNetProfit => (totalRevenuePaisa - totalMaterialCostPaisa - totalLaborCostPaisa) / 100;
}

/// Create repair request
class CreateRepairRequest {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String itemDescription;
  final String? itemCategory;
  final String? metalType;
  final double? weightGrams;
  final String? productId;
  final List<RepairWorkItem> workItems;
  final String? customerComplaint;
  final RepairPriority priority;
  final DateTime? promisedDate;
  final int? estimatedDays;
  final int? estimatedCostPaisa;
  final List<String>? conditionPhotoUrls;

  CreateRepairRequest({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.itemDescription,
    this.itemCategory,
    this.metalType,
    this.weightGrams,
    this.productId,
    required this.workItems,
    this.customerComplaint,
    this.priority = RepairPriority.normal,
    this.promisedDate,
    this.estimatedDays,
    this.estimatedCostPaisa,
    this.conditionPhotoUrls,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'itemDescription': itemDescription,
    'itemCategory': itemCategory,
    'metalType': metalType,
    'weightGrams': weightGrams,
    'productId': productId,
    'workItems': workItems.map((w) => w.toJson()).toList(),
    'customerComplaint': customerComplaint,
    'priority': priority.name,
    'promisedDate': promisedDate?.toIso8601String(),
    'estimatedDays': estimatedDays,
    'estimatedCostPaisa': estimatedCostPaisa,
    'conditionPhotoUrls': conditionPhotoUrls,
  };
}

/// Update repair request
class UpdateRepairRequest {
  final List<RepairWorkItem>? workItems;
  final RepairStatus? status;
  final RepairPriority? priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? damageAssessment;
  final String? recommendedWork;
  final int? estimatedCostPaisa;
  final int? estimatedDays;
  final DateTime? promisedDate;
  final int? actualCostPaisa;
  final int? materialCostPaisa;
  final int? laborCostPaisa;
  final int? additionalChargesPaisa;
  final String? additionalChargesNote;
  final int? advanceReceivedPaisa;
  final int? warrantyDays;
  final int? customerRating;
  final String? customerFeedback;

  UpdateRepairRequest({
    this.workItems,
    this.status,
    this.priority,
    this.assignedTo,
    this.assignedToName,
    this.damageAssessment,
    this.recommendedWork,
    this.estimatedCostPaisa,
    this.estimatedDays,
    this.promisedDate,
    this.actualCostPaisa,
    this.materialCostPaisa,
    this.laborCostPaisa,
    this.additionalChargesPaisa,
    this.additionalChargesNote,
    this.advanceReceivedPaisa,
    this.warrantyDays,
    this.customerRating,
    this.customerFeedback,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (workItems != null) data['workItems'] = workItems!.map((w) => w.toJson()).toList();
    if (status != null) data['status'] = status!.name;
    if (priority != null) data['priority'] = priority!.name;
    if (assignedTo != null) data['assignedTo'] = assignedTo;
    if (assignedToName != null) data['assignedToName'] = assignedToName;
    if (damageAssessment != null) data['damageAssessment'] = damageAssessment;
    if (recommendedWork != null) data['recommendedWork'] = recommendedWork;
    if (estimatedCostPaisa != null) data['estimatedCostPaisa'] = estimatedCostPaisa;
    if (estimatedDays != null) data['estimatedDays'] = estimatedDays;
    if (promisedDate != null) data['promisedDate'] = promisedDate!.toIso8601String();
    if (actualCostPaisa != null) data['actualCostPaisa'] = actualCostPaisa;
    if (materialCostPaisa != null) data['materialCostPaisa'] = materialCostPaisa;
    if (laborCostPaisa != null) data['laborCostPaisa'] = laborCostPaisa;
    if (additionalChargesPaisa != null) data['additionalChargesPaisa'] = additionalChargesPaisa;
    if (additionalChargesNote != null) data['additionalChargesNote'] = additionalChargesNote;
    if (advanceReceivedPaisa != null) data['advanceReceivedPaisa'] = advanceReceivedPaisa;
    if (warrantyDays != null) data['warrantyDays'] = warrantyDays;
    if (customerRating != null) data['customerRating'] = customerRating;
    if (customerFeedback != null) data['customerFeedback'] = customerFeedback;
    return data;
  }
}
