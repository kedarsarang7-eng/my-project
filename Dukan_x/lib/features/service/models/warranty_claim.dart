/// Warranty Claim Model
/// Represents a formal warranty claim for devices under warranty
/// Separate from ServiceJob - tracks claim-specific data
library;

/// Status lifecycle for warranty claims
enum WarrantyClaimStatus {
  filed,          // Claim filed, awaiting review
  underReview,    // Under warranty verification
  approved,       // Claim approved, parts/service authorized
  partsOrdered,   // Replacement parts ordered
  inRepair,       // Device in repair
  completed,      // Repair completed
  rejected,       // Claim rejected (not under warranty/damage not covered)
  closed,         // Claim closed and delivered
}

extension WarrantyClaimStatusExtension on WarrantyClaimStatus {
  String get value {
    switch (this) {
      case WarrantyClaimStatus.filed:
        return 'FILED';
      case WarrantyClaimStatus.underReview:
        return 'UNDER_REVIEW';
      case WarrantyClaimStatus.approved:
        return 'APPROVED';
      case WarrantyClaimStatus.partsOrdered:
        return 'PARTS_ORDERED';
      case WarrantyClaimStatus.inRepair:
        return 'IN_REPAIR';
      case WarrantyClaimStatus.completed:
        return 'COMPLETED';
      case WarrantyClaimStatus.rejected:
        return 'REJECTED';
      case WarrantyClaimStatus.closed:
        return 'CLOSED';
    }
  }

  String get displayName {
    switch (this) {
      case WarrantyClaimStatus.filed:
        return 'Filed';
      case WarrantyClaimStatus.underReview:
        return 'Under Review';
      case WarrantyClaimStatus.approved:
        return 'Approved';
      case WarrantyClaimStatus.partsOrdered:
        return 'Parts Ordered';
      case WarrantyClaimStatus.inRepair:
        return 'In Repair';
      case WarrantyClaimStatus.completed:
        return 'Completed';
      case WarrantyClaimStatus.rejected:
        return 'Rejected';
      case WarrantyClaimStatus.closed:
        return 'Closed';
    }
  }

  static WarrantyClaimStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'FILED':
        return WarrantyClaimStatus.filed;
      case 'UNDER_REVIEW':
        return WarrantyClaimStatus.underReview;
      case 'APPROVED':
        return WarrantyClaimStatus.approved;
      case 'PARTS_ORDERED':
        return WarrantyClaimStatus.partsOrdered;
      case 'IN_REPAIR':
        return WarrantyClaimStatus.inRepair;
      case 'COMPLETED':
        return WarrantyClaimStatus.completed;
      case 'REJECTED':
        return WarrantyClaimStatus.rejected;
      case 'CLOSED':
        return WarrantyClaimStatus.closed;
      default:
        return WarrantyClaimStatus.filed;
    }
  }
}

/// Rejection reason categories
enum RejectionReason {
  outOfWarranty,
  physicalDamage,
  liquidDamage,
  unauthorizedRepair,
  missingDocuments,
  other,
}

extension RejectionReasonExtension on RejectionReason {
  String get value {
    switch (this) {
      case RejectionReason.outOfWarranty:
        return 'OUT_OF_WARRANTY';
      case RejectionReason.physicalDamage:
        return 'PHYSICAL_DAMAGE';
      case RejectionReason.liquidDamage:
        return 'LIQUID_DAMAGE';
      case RejectionReason.unauthorizedRepair:
        return 'UNAUTHORIZED_REPAIR';
      case RejectionReason.missingDocuments:
        return 'MISSING_DOCUMENTS';
      case RejectionReason.other:
        return 'OTHER';
    }
  }

  String get displayName {
    switch (this) {
      case RejectionReason.outOfWarranty:
        return 'Out of Warranty Period';
      case RejectionReason.physicalDamage:
        return 'Physical Damage Not Covered';
      case RejectionReason.liquidDamage:
        return 'Liquid Damage Not Covered';
      case RejectionReason.unauthorizedRepair:
        return 'Unauthorized Repair Voided Warranty';
      case RejectionReason.missingDocuments:
        return 'Missing Required Documents';
      case RejectionReason.other:
        return 'Other';
    }
  }
}

/// Part replaced under warranty
class WarrantyClaimPart {
  final String id;
  final String? productId;           // Internal product ID (if from inventory)
  final String partName;             // Name of the part
  final String? partNumber;          // Manufacturer part number
  final double quantity;
  final double unitCost;             // Cost to us (for P&L tracking)
  final double totalCost;
  final String? supplierName;        // Where we got the part
  final String? serialNumber;        // Serial of the replacement part
  final bool isUnderWarranty;        // Is this part itself under warranty?
  final DateTime? replacedAt;
  final String? replacedByTechnicianId;
  final String? notes;
  final DateTime createdAt;

  WarrantyClaimPart({
    required this.id,
    this.productId,
    required this.partName,
    this.partNumber,
    this.quantity = 1,
    required this.unitCost,
    required this.totalCost,
    this.supplierName,
    this.serialNumber,
    this.isUnderWarranty = false,
    this.replacedAt,
    this.replacedByTechnicianId,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'partName': partName,
      'partNumber': partNumber,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'supplierName': supplierName,
      'serialNumber': serialNumber,
      'isUnderWarranty': isUnderWarranty,
      'replacedAt': replacedAt?.toIso8601String(),
      'replacedByTechnicianId': replacedByTechnicianId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WarrantyClaimPart.fromMap(Map<String, dynamic> map) {
    return WarrantyClaimPart(
      id: map['id'] ?? '',
      productId: map['productId'],
      partName: map['partName'] ?? '',
      partNumber: map['partNumber'],
      quantity: (map['quantity'] ?? 1).toDouble(),
      unitCost: (map['unitCost'] ?? 0).toDouble(),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      supplierName: map['supplierName'],
      serialNumber: map['serialNumber'],
      isUnderWarranty: map['isUnderWarranty'] == true,
      replacedAt: map['replacedAt'] != null
          ? DateTime.tryParse(map['replacedAt'])
          : null,
      replacedByTechnicianId: map['replacedByTechnicianId'],
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  WarrantyClaimPart copyWith({
    String? id,
    String? productId,
    String? partName,
    String? partNumber,
    double? quantity,
    double? unitCost,
    double? totalCost,
    String? supplierName,
    String? serialNumber,
    bool? isUnderWarranty,
    DateTime? replacedAt,
    String? replacedByTechnicianId,
    String? notes,
    DateTime? createdAt,
  }) {
    return WarrantyClaimPart(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      partName: partName ?? this.partName,
      partNumber: partNumber ?? this.partNumber,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      supplierName: supplierName ?? this.supplierName,
      serialNumber: serialNumber ?? this.serialNumber,
      isUnderWarranty: isUnderWarranty ?? this.isUnderWarranty,
      replacedAt: replacedAt ?? this.replacedAt,
      replacedByTechnicianId: replacedByTechnicianId ?? this.replacedByTechnicianId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Warranty Claim model
class WarrantyClaim {
  final String id;
  final String userId;
  final String claimNumber;          // Auto-generated: WCL-YYMM-0001

  // Original sale reference
  final String originalBillId;
  final String? originalInvoiceNumber;
  final String? originalSaleDate;

  // Device info
  final String productId;
  final String productName;
  final String? brand;
  final String? model;
  final String imeiOrSerial;
  final String? color;
  final String? storage;

  // Customer info
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;

  // Claim details
  final String issueDescription;
  final List<String> symptoms;
  final List<String> issuePhotos;      // URLs to uploaded photos

  // Warranty verification
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final int warrantyPeriodMonths;
  final bool isUnderWarranty;
  final String? warrantyVerificationNotes;

  // Status tracking
  final WarrantyClaimStatus status;
  final DateTime filedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;

  // Assignment
  final String? reviewedByUserId;
  final String? reviewedByName;
  final String? assignedTechnicianId;
  final String? assignedTechnicianName;

  // Parts replaced under warranty
  final List<WarrantyClaimPart> partsReplaced;
  final double totalPartsCost;
  final double laborCost;
  final double totalClaimCost;         // Total cost to us for this claim

  // Rejection (if applicable)
  final RejectionReason? rejectionReason;
  final String? rejectionNotes;

  // Service job linkage (optional - may create service job for repair)
  final String? linkedServiceJobId;

  // Resolution
  final String? resolutionNotes;
  final String? workDone;

  // Financial tracking
  final bool isReimbursedBySupplier;   // Did supplier reimburse us?
  final double? reimbursementAmount;
  final DateTime? reimbursedAt;
  final String? reimbursementReference;

  // Sync
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  WarrantyClaim({
    required this.id,
    required this.userId,
    required this.claimNumber,
    required this.originalBillId,
    this.originalInvoiceNumber,
    this.originalSaleDate,
    required this.productId,
    required this.productName,
    this.brand,
    this.model,
    required this.imeiOrSerial,
    this.color,
    this.storage,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.issueDescription,
    this.symptoms = const [],
    this.issuePhotos = const [],
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyPeriodMonths = 0,
    this.isUnderWarranty = false,
    this.warrantyVerificationNotes,
    this.status = WarrantyClaimStatus.filed,
    required this.filedAt,
    this.reviewedAt,
    this.approvedAt,
    this.completedAt,
    this.closedAt,
    this.reviewedByUserId,
    this.reviewedByName,
    this.assignedTechnicianId,
    this.assignedTechnicianName,
    this.partsReplaced = const [],
    this.totalPartsCost = 0,
    this.laborCost = 0,
    this.totalClaimCost = 0,
    this.rejectionReason,
    this.rejectionNotes,
    this.linkedServiceJobId,
    this.resolutionNotes,
    this.workDone,
    this.isReimbursedBySupplier = false,
    this.reimbursementAmount,
    this.reimbursedAt,
    this.reimbursementReference,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Days since claim was filed
  int get daysSinceFiled {
    return DateTime.now().difference(filedAt).inDays;
  }

  /// Is claim still active (not closed/rejected)
  bool get isActive =>
      status != WarrantyClaimStatus.closed &&
      status != WarrantyClaimStatus.rejected;

  /// Total cost formatted for display
  String get formattedTotalCost => '₹${totalClaimCost.toStringAsFixed(2)}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'claimNumber': claimNumber,
      'originalBillId': originalBillId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'originalSaleDate': originalSaleDate,
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'model': model,
      'imeiOrSerial': imeiOrSerial,
      'color': color,
      'storage': storage,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'issueDescription': issueDescription,
      'symptomsJson': symptoms.join(', '),
      'issuePhotosJson': issuePhotos.join(','),
      'warrantyStartDate': warrantyStartDate?.toIso8601String(),
      'warrantyEndDate': warrantyEndDate?.toIso8601String(),
      'warrantyPeriodMonths': warrantyPeriodMonths,
      'isUnderWarranty': isUnderWarranty,
      'warrantyVerificationNotes': warrantyVerificationNotes,
      'status': status.value,
      'filedAt': filedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'reviewedByUserId': reviewedByUserId,
      'reviewedByName': reviewedByName,
      'assignedTechnicianId': assignedTechnicianId,
      'assignedTechnicianName': assignedTechnicianName,
      'partsReplacedJson': partsReplaced.map((p) => p.toMap()).toList(),
      'totalPartsCost': totalPartsCost,
      'laborCost': laborCost,
      'totalClaimCost': totalClaimCost,
      'rejectionReason': rejectionReason?.value,
      'rejectionNotes': rejectionNotes,
      'linkedServiceJobId': linkedServiceJobId,
      'resolutionNotes': resolutionNotes,
      'workDone': workDone,
      'isReimbursedBySupplier': isReimbursedBySupplier,
      'reimbursementAmount': reimbursementAmount,
      'reimbursedAt': reimbursedAt?.toIso8601String(),
      'reimbursementReference': reimbursementReference,
      'isSynced': isSynced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WarrantyClaim.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.cast<String>();
      if (value is String && value.isNotEmpty) {
        return value.split(', ').where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    List<WarrantyClaimPart> parseParts(dynamic value) {
      if (value == null) return [];
      try {
        List<dynamic> list;
        if (value is String) {
          list = [];
        } else if (value is List) {
          list = value;
        } else {
          return [];
        }
        return list.map((p) => WarrantyClaimPart.fromMap(p)).toList();
      } catch (_) {
        return [];
      }
    }

    return WarrantyClaim(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      claimNumber: map['claimNumber'] ?? '',
      originalBillId: map['originalBillId'] ?? '',
      originalInvoiceNumber: map['originalInvoiceNumber'],
      originalSaleDate: map['originalSaleDate'],
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      brand: map['brand'],
      model: map['model'],
      imeiOrSerial: map['imeiOrSerial'] ?? '',
      color: map['color'],
      storage: map['storage'],
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerEmail: map['customerEmail'],
      issueDescription: map['issueDescription'] ?? '',
      symptoms: parseStringList(map['symptomsJson']),
      issuePhotos: parseStringList(map['issuePhotosJson']),
      warrantyStartDate: map['warrantyStartDate'] != null
          ? DateTime.tryParse(map['warrantyStartDate'])
          : null,
      warrantyEndDate: map['warrantyEndDate'] != null
          ? DateTime.tryParse(map['warrantyEndDate'])
          : null,
      warrantyPeriodMonths: map['warrantyPeriodMonths'] ?? 0,
      isUnderWarranty: map['isUnderWarranty'] == true,
      warrantyVerificationNotes: map['warrantyVerificationNotes'],
      status: WarrantyClaimStatusExtension.fromString(map['status'] ?? 'FILED'),
      filedAt: DateTime.tryParse(map['filedAt'] ?? '') ?? DateTime.now(),
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'])
          : null,
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      closedAt: map['closedAt'] != null
          ? DateTime.tryParse(map['closedAt'])
          : null,
      reviewedByUserId: map['reviewedByUserId'],
      reviewedByName: map['reviewedByName'],
      assignedTechnicianId: map['assignedTechnicianId'],
      assignedTechnicianName: map['assignedTechnicianName'],
      partsReplaced: parseParts(map['partsReplacedJson']),
      totalPartsCost: (map['totalPartsCost'] ?? 0).toDouble(),
      laborCost: (map['laborCost'] ?? 0).toDouble(),
      totalClaimCost: (map['totalClaimCost'] ?? 0).toDouble(),
      rejectionReason: map['rejectionReason'] != null
          ? RejectionReason.values.firstWhere(
              (r) => r.value == map['rejectionReason'],
              orElse: () => RejectionReason.other,
            )
          : null,
      rejectionNotes: map['rejectionNotes'],
      linkedServiceJobId: map['linkedServiceJobId'],
      resolutionNotes: map['resolutionNotes'],
      workDone: map['workDone'],
      isReimbursedBySupplier: map['isReimbursedBySupplier'] == true,
      reimbursementAmount: map['reimbursementAmount']?.toDouble(),
      reimbursedAt: map['reimbursedAt'] != null
          ? DateTime.tryParse(map['reimbursedAt'])
          : null,
      reimbursementReference: map['reimbursementReference'],
      isSynced: map['isSynced'] == true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  WarrantyClaim copyWith({
    String? id,
    String? userId,
    String? claimNumber,
    String? originalBillId,
    String? originalInvoiceNumber,
    String? originalSaleDate,
    String? productId,
    String? productName,
    String? brand,
    String? model,
    String? imeiOrSerial,
    String? color,
    String? storage,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? issueDescription,
    List<String>? symptoms,
    List<String>? issuePhotos,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    int? warrantyPeriodMonths,
    bool? isUnderWarranty,
    String? warrantyVerificationNotes,
    WarrantyClaimStatus? status,
    DateTime? filedAt,
    DateTime? reviewedAt,
    DateTime? approvedAt,
    DateTime? completedAt,
    DateTime? closedAt,
    String? reviewedByUserId,
    String? reviewedByName,
    String? assignedTechnicianId,
    String? assignedTechnicianName,
    List<WarrantyClaimPart>? partsReplaced,
    double? totalPartsCost,
    double? laborCost,
    double? totalClaimCost,
    RejectionReason? rejectionReason,
    String? rejectionNotes,
    String? linkedServiceJobId,
    String? resolutionNotes,
    String? workDone,
    bool? isReimbursedBySupplier,
    double? reimbursementAmount,
    DateTime? reimbursedAt,
    String? reimbursementReference,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarrantyClaim(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      claimNumber: claimNumber ?? this.claimNumber,
      originalBillId: originalBillId ?? this.originalBillId,
      originalInvoiceNumber: originalInvoiceNumber ?? this.originalInvoiceNumber,
      originalSaleDate: originalSaleDate ?? this.originalSaleDate,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      imeiOrSerial: imeiOrSerial ?? this.imeiOrSerial,
      color: color ?? this.color,
      storage: storage ?? this.storage,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      issueDescription: issueDescription ?? this.issueDescription,
      symptoms: symptoms ?? this.symptoms,
      issuePhotos: issuePhotos ?? this.issuePhotos,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      warrantyPeriodMonths: warrantyPeriodMonths ?? this.warrantyPeriodMonths,
      isUnderWarranty: isUnderWarranty ?? this.isUnderWarranty,
      warrantyVerificationNotes: warrantyVerificationNotes ?? this.warrantyVerificationNotes,
      status: status ?? this.status,
      filedAt: filedAt ?? this.filedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      completedAt: completedAt ?? this.completedAt,
      closedAt: closedAt ?? this.closedAt,
      reviewedByUserId: reviewedByUserId ?? this.reviewedByUserId,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      assignedTechnicianName: assignedTechnicianName ?? this.assignedTechnicianName,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      totalPartsCost: totalPartsCost ?? this.totalPartsCost,
      laborCost: laborCost ?? this.laborCost,
      totalClaimCost: totalClaimCost ?? this.totalClaimCost,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectionNotes: rejectionNotes ?? this.rejectionNotes,
      linkedServiceJobId: linkedServiceJobId ?? this.linkedServiceJobId,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      workDone: workDone ?? this.workDone,
      isReimbursedBySupplier: isReimbursedBySupplier ?? this.isReimbursedBySupplier,
      reimbursementAmount: reimbursementAmount ?? this.reimbursementAmount,
      reimbursedAt: reimbursedAt ?? this.reimbursedAt,
      reimbursementReference: reimbursementReference ?? this.reimbursementReference,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
