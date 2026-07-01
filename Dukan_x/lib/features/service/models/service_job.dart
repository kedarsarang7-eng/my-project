/// Service Job Model
/// Represents a repair/service job card for mobile/computer shops
library;

import 'dart:convert';

/// Status lifecycle for service jobs
enum ServiceJobStatus {
  received, // Device just received
  diagnosed, // Problem identified
  waitingApproval, // Estimate sent, waiting for customer approval
  approved, // Customer approved
  waitingParts, // Waiting for parts to arrive
  inProgress, // Repair in progress
  completed, // Repair completed, ready for testing
  ready, // Tested & ready for delivery
  delivered, // Device delivered to customer
  cancelled, // Job cancelled
}

extension ServiceJobStatusExtension on ServiceJobStatus {
  String get value {
    switch (this) {
      case ServiceJobStatus.received:
        return 'RECEIVED';
      case ServiceJobStatus.diagnosed:
        return 'DIAGNOSED';
      case ServiceJobStatus.waitingApproval:
        return 'WAITING_APPROVAL';
      case ServiceJobStatus.approved:
        return 'APPROVED';
      case ServiceJobStatus.waitingParts:
        return 'WAITING_PARTS';
      case ServiceJobStatus.inProgress:
        return 'IN_PROGRESS';
      case ServiceJobStatus.completed:
        return 'COMPLETED';
      case ServiceJobStatus.ready:
        return 'READY';
      case ServiceJobStatus.delivered:
        return 'DELIVERED';
      case ServiceJobStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get displayName {
    switch (this) {
      case ServiceJobStatus.received:
        return 'Received';
      case ServiceJobStatus.diagnosed:
        return 'Diagnosed';
      case ServiceJobStatus.waitingApproval:
        return 'Waiting Approval';
      case ServiceJobStatus.approved:
        return 'Approved';
      case ServiceJobStatus.waitingParts:
        return 'Waiting for Parts';
      case ServiceJobStatus.inProgress:
        return 'In Progress';
      case ServiceJobStatus.completed:
        return 'Completed';
      case ServiceJobStatus.ready:
        return 'Ready for Pickup';
      case ServiceJobStatus.delivered:
        return 'Delivered';
      case ServiceJobStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ServiceJobStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RECEIVED':
        return ServiceJobStatus.received;
      case 'DIAGNOSED':
        return ServiceJobStatus.diagnosed;
      case 'WAITING_APPROVAL':
        return ServiceJobStatus.waitingApproval;
      case 'APPROVED':
        return ServiceJobStatus.approved;
      case 'WAITING_PARTS':
        return ServiceJobStatus.waitingParts;
      case 'IN_PROGRESS':
        return ServiceJobStatus.inProgress;
      case 'COMPLETED':
        return ServiceJobStatus.completed;
      case 'READY':
        return ServiceJobStatus.ready;
      case 'DELIVERED':
        return ServiceJobStatus.delivered;
      case 'CANCELLED':
        return ServiceJobStatus.cancelled;
      default:
        return ServiceJobStatus.received;
    }
  }
}

/// Device type enum
enum DeviceType { mobile, laptop, desktop, tablet, other }

extension DeviceTypeExtension on DeviceType {
  String get value {
    switch (this) {
      case DeviceType.mobile:
        return 'MOBILE';
      case DeviceType.laptop:
        return 'LAPTOP';
      case DeviceType.desktop:
        return 'DESKTOP';
      case DeviceType.tablet:
        return 'TABLET';
      case DeviceType.other:
        return 'OTHER';
    }
  }

  String get displayName {
    switch (this) {
      case DeviceType.mobile:
        return 'Mobile Phone';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.desktop:
        return 'Desktop';
      case DeviceType.tablet:
        return 'Tablet';
      case DeviceType.other:
        return 'Other';
    }
  }

  static DeviceType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'MOBILE':
        return DeviceType.mobile;
      case 'LAPTOP':
        return DeviceType.laptop;
      case 'DESKTOP':
        return DeviceType.desktop;
      case 'TABLET':
        return DeviceType.tablet;
      default:
        return DeviceType.other;
    }
  }
}

/// Priority levels
enum ServicePriority { low, normal, high, urgent }

extension ServicePriorityExtension on ServicePriority {
  String get value {
    switch (this) {
      case ServicePriority.low:
        return 'LOW';
      case ServicePriority.normal:
        return 'NORMAL';
      case ServicePriority.high:
        return 'HIGH';
      case ServicePriority.urgent:
        return 'URGENT';
    }
  }

  String get displayName {
    switch (this) {
      case ServicePriority.low:
        return 'Low';
      case ServicePriority.normal:
        return 'Normal';
      case ServicePriority.high:
        return 'High';
      case ServicePriority.urgent:
        return 'Urgent';
    }
  }

  static ServicePriority fromString(String value) {
    switch (value.toUpperCase()) {
      case 'LOW':
        return ServicePriority.low;
      case 'HIGH':
        return ServicePriority.high;
      case 'URGENT':
        return ServicePriority.urgent;
      default:
        return ServicePriority.normal;
    }
  }
}

/// Service Job model
class ServiceJob {
  final String id;
  final String userId;
  final String jobNumber;

  // Customer info
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? customerAddress;

  // Device info
  final DeviceType deviceType;
  final String brand;
  final String model;
  final String? imeiOrSerial;
  final String? color;
  final List<String> accessories;
  final String? deviceConditionNotes;
  final List<String> devicePhotos;

  // Problem
  final String problemDescription;
  final List<String> symptoms;

  // Warranty
  final bool isUnderWarranty;
  final String? originalBillId;
  final String? imeiSerialId;

  // Status
  final ServiceJobStatus status;
  final ServicePriority priority;

  // Assignment
  final String? assignedTechnicianId;
  final String? assignedTechnicianName;

  // Diagnosis
  final String? diagnosis;
  final DateTime? diagnosedAt;

  // Estimates
  final double estimatedLaborCost;
  final double estimatedPartsCost;
  final double estimatedTotal;
  final bool customerApproved;
  final DateTime? approvedAt;

  // Actual costs
  final double actualLaborCost;
  final double actualPartsCost;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;

  // Work
  final String? workDone;
  final List<ServiceJobPart> partsUsed;

  // Payment
  final String paymentStatus;
  final double advanceReceived;
  final double amountPaid;
  final String? paymentMode;
  final String? billId;

  // Timeline
  final DateTime receivedAt;
  final DateTime? expectedDelivery;
  final DateTime? completedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  // Communication
  final bool smsNotificationsEnabled;

  // Notes
  final String? internalNotes;

  // Sync
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceJob({
    required this.id,
    required this.userId,
    required this.jobNumber,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    required this.deviceType,
    required this.brand,
    required this.model,
    this.imeiOrSerial,
    this.color,
    this.accessories = const [],
    this.deviceConditionNotes,
    this.devicePhotos = const [],
    required this.problemDescription,
    this.symptoms = const [],
    this.isUnderWarranty = false,
    this.originalBillId,
    this.imeiSerialId,
    this.status = ServiceJobStatus.received,
    this.priority = ServicePriority.normal,
    this.assignedTechnicianId,
    this.assignedTechnicianName,
    this.diagnosis,
    this.diagnosedAt,
    this.estimatedLaborCost = 0,
    this.estimatedPartsCost = 0,
    this.estimatedTotal = 0,
    this.customerApproved = false,
    this.approvedAt,
    this.actualLaborCost = 0,
    this.actualPartsCost = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.grandTotal = 0,
    this.workDone,
    this.partsUsed = const [],
    this.paymentStatus = 'PENDING',
    this.advanceReceived = 0,
    this.amountPaid = 0,
    this.paymentMode,
    this.billId,
    required this.receivedAt,
    this.expectedDelivery,
    this.completedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    this.smsNotificationsEnabled = true,
    this.internalNotes,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Balance amount pending
  double get balanceAmount => grandTotal - amountPaid;

  /// Whether job is still active (not delivered/cancelled)
  bool get isActive =>
      status != ServiceJobStatus.delivered &&
      status != ServiceJobStatus.cancelled;

  /// Whether customer can be charged (job completed)
  bool get isChargeable =>
      status == ServiceJobStatus.completed ||
      status == ServiceJobStatus.ready ||
      status == ServiceJobStatus.delivered;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'jobNumber': jobNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'deviceType': deviceType.value,
      'brand': brand,
      'model': model,
      'imeiOrSerial': imeiOrSerial,
      'color': color,
      'accessories': jsonEncode(accessories),
      'deviceConditionNotes': deviceConditionNotes,
      'devicePhotosJson': jsonEncode(devicePhotos),
      'problemDescription': problemDescription,
      'symptomsJson': jsonEncode(symptoms),
      'isUnderWarranty': isUnderWarranty,
      'originalBillId': originalBillId,
      'imeiSerialId': imeiSerialId,
      'status': status.value,
      'priority': priority.value,
      'assignedTechnicianId': assignedTechnicianId,
      'assignedTechnicianName': assignedTechnicianName,
      'diagnosis': diagnosis,
      'diagnosedAt': diagnosedAt?.toIso8601String(),
      'estimatedLaborCost': estimatedLaborCost,
      'estimatedPartsCost': estimatedPartsCost,
      'estimatedTotal': estimatedTotal,
      'customerApproved': customerApproved,
      'approvedAt': approvedAt?.toIso8601String(),
      'actualLaborCost': actualLaborCost,
      'actualPartsCost': actualPartsCost,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'workDone': workDone,
      'partsUsedJson': jsonEncode(partsUsed.map((p) => p.toMap()).toList()),
      'paymentStatus': paymentStatus,
      'advanceReceived': advanceReceived,
      'amountPaid': amountPaid,
      'paymentMode': paymentMode,
      'billId': billId,
      'receivedAt': receivedAt.toIso8601String(),
      'expectedDelivery': expectedDelivery?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'smsNotificationsEnabled': smsNotificationsEnabled,
      'internalNotes': internalNotes,
      'isSynced': isSynced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ServiceJob.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.cast<String>();
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
      }
      return [];
    }

    List<ServiceJobPart> parsePartsUsed(dynamic value) {
      if (value == null) return [];
      try {
        List<dynamic> list;
        if (value is String) {
          list = jsonDecode(value);
        } else if (value is List) {
          list = value;
        } else {
          return [];
        }
        return list.map((p) => ServiceJobPart.fromMap(p)).toList();
      } catch (_) {
        return [];
      }
    }

    return ServiceJob(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      jobNumber: map['jobNumber'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerEmail: map['customerEmail'],
      customerAddress: map['customerAddress'],
      deviceType: DeviceTypeExtension.fromString(map['deviceType'] ?? ''),
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      imeiOrSerial: map['imeiOrSerial'],
      color: map['color'],
      accessories: parseStringList(map['accessories']),
      deviceConditionNotes: map['deviceConditionNotes'],
      devicePhotos: parseStringList(map['devicePhotosJson']),
      problemDescription: map['problemDescription'] ?? '',
      symptoms: parseStringList(map['symptomsJson']),
      isUnderWarranty: map['isUnderWarranty'] == true,
      originalBillId: map['originalBillId'],
      imeiSerialId: map['imeiSerialId'],
      status: ServiceJobStatusExtension.fromString(map['status'] ?? 'RECEIVED'),
      priority: ServicePriorityExtension.fromString(
        map['priority'] ?? 'NORMAL',
      ),
      assignedTechnicianId: map['assignedTechnicianId'],
      assignedTechnicianName: map['assignedTechnicianName'],
      diagnosis: map['diagnosis'],
      diagnosedAt: map['diagnosedAt'] != null
          ? DateTime.tryParse(map['diagnosedAt'])
          : null,
      estimatedLaborCost: (map['estimatedLaborCost'] ?? 0).toDouble(),
      estimatedPartsCost: (map['estimatedPartsCost'] ?? 0).toDouble(),
      estimatedTotal: (map['estimatedTotal'] ?? 0).toDouble(),
      customerApproved: map['customerApproved'] == true,
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'])
          : null,
      actualLaborCost: (map['actualLaborCost'] ?? 0).toDouble(),
      actualPartsCost: (map['actualPartsCost'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      workDone: map['workDone'],
      partsUsed: parsePartsUsed(map['partsUsedJson']),
      paymentStatus: map['paymentStatus'] ?? 'PENDING',
      advanceReceived: (map['advanceReceived'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      paymentMode: map['paymentMode'],
      billId: map['billId'],
      receivedAt: DateTime.tryParse(map['receivedAt'] ?? '') ?? DateTime.now(),
      expectedDelivery: map['expectedDelivery'] != null
          ? DateTime.tryParse(map['expectedDelivery'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.tryParse(map['deliveredAt'])
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.tryParse(map['cancelledAt'])
          : null,
      cancellationReason: map['cancellationReason'],
      smsNotificationsEnabled: map['smsNotificationsEnabled'] ?? true,
      internalNotes: map['internalNotes'],
      isSynced: map['isSynced'] == true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  ServiceJob copyWith({
    String? id,
    String? userId,
    String? jobNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    DeviceType? deviceType,
    String? brand,
    String? model,
    String? imeiOrSerial,
    String? color,
    List<String>? accessories,
    String? deviceConditionNotes,
    List<String>? devicePhotos,
    String? problemDescription,
    List<String>? symptoms,
    bool? isUnderWarranty,
    String? originalBillId,
    String? imeiSerialId,
    ServiceJobStatus? status,
    ServicePriority? priority,
    String? assignedTechnicianId,
    String? assignedTechnicianName,
    String? diagnosis,
    DateTime? diagnosedAt,
    double? estimatedLaborCost,
    double? estimatedPartsCost,
    double? estimatedTotal,
    bool? customerApproved,
    DateTime? approvedAt,
    double? actualLaborCost,
    double? actualPartsCost,
    double? discountAmount,
    double? taxAmount,
    double? grandTotal,
    String? workDone,
    List<ServiceJobPart>? partsUsed,
    String? paymentStatus,
    double? advanceReceived,
    double? amountPaid,
    String? paymentMode,
    String? billId,
    DateTime? receivedAt,
    DateTime? expectedDelivery,
    DateTime? completedAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool? smsNotificationsEnabled,
    String? internalNotes,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      jobNumber: jobNumber ?? this.jobNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      deviceType: deviceType ?? this.deviceType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      imeiOrSerial: imeiOrSerial ?? this.imeiOrSerial,
      color: color ?? this.color,
      accessories: accessories ?? this.accessories,
      deviceConditionNotes: deviceConditionNotes ?? this.deviceConditionNotes,
      devicePhotos: devicePhotos ?? this.devicePhotos,
      problemDescription: problemDescription ?? this.problemDescription,
      symptoms: symptoms ?? this.symptoms,
      isUnderWarranty: isUnderWarranty ?? this.isUnderWarranty,
      originalBillId: originalBillId ?? this.originalBillId,
      imeiSerialId: imeiSerialId ?? this.imeiSerialId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      assignedTechnicianName:
          assignedTechnicianName ?? this.assignedTechnicianName,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosedAt: diagnosedAt ?? this.diagnosedAt,
      estimatedLaborCost: estimatedLaborCost ?? this.estimatedLaborCost,
      estimatedPartsCost: estimatedPartsCost ?? this.estimatedPartsCost,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      customerApproved: customerApproved ?? this.customerApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      actualLaborCost: actualLaborCost ?? this.actualLaborCost,
      actualPartsCost: actualPartsCost ?? this.actualPartsCost,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      workDone: workDone ?? this.workDone,
      partsUsed: partsUsed ?? this.partsUsed,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      advanceReceived: advanceReceived ?? this.advanceReceived,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMode: paymentMode ?? this.paymentMode,
      billId: billId ?? this.billId,
      receivedAt: receivedAt ?? this.receivedAt,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
      completedAt: completedAt ?? this.completedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      smsNotificationsEnabled:
          smsNotificationsEnabled ?? this.smsNotificationsEnabled,
      internalNotes: internalNotes ?? this.internalNotes,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Service Job Part model
class ServiceJobPart {
  final String id;
  final String serviceJobId;
  final String? productId;
  final String partName;
  final double quantity;
  final String unit;
  final double unitCost;
  final double totalCost;
  final bool isFromInventory;
  final String? notes;
  final DateTime createdAt;

  ServiceJobPart({
    required this.id,
    required this.serviceJobId,
    this.productId,
    required this.partName,
    this.quantity = 1,
    this.unit = 'pcs',
    required this.unitCost,
    required this.totalCost,
    this.isFromInventory = false,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceJobId': serviceJobId,
      'productId': productId,
      'partName': partName,
      'quantity': quantity,
      'unit': unit,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'isFromInventory': isFromInventory,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ServiceJobPart.fromMap(Map<String, dynamic> map) {
    return ServiceJobPart(
      id: map['id'] ?? '',
      serviceJobId: map['serviceJobId'] ?? '',
      productId: map['productId'],
      partName: map['partName'] ?? '',
      quantity: (map['quantity'] ?? 1).toDouble(),
      unit: map['unit'] ?? 'pcs',
      unitCost: (map['unitCost'] ?? 0).toDouble(),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      isFromInventory: map['isFromInventory'] == true,
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
