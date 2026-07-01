// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jewellery_repair_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RepairStatusUpdate _$RepairStatusUpdateFromJson(Map<String, dynamic> json) =>
    _RepairStatusUpdate(
      status: $enumDecode(_$RepairStatusEnumMap, json['status']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      updatedBy: json['updatedBy'] as String,
      notes: json['notes'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$RepairStatusUpdateToJson(_RepairStatusUpdate instance) =>
    <String, dynamic>{
      'status': _$RepairStatusEnumMap[instance.status]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'updatedBy': instance.updatedBy,
      'notes': instance.notes,
      'photoUrls': instance.photoUrls,
    };

const _$RepairStatusEnumMap = {
  RepairStatus.pending: 'pending',
  RepairStatus.assessed: 'assessed',
  RepairStatus.approved: 'approved',
  RepairStatus.inProgress: 'inProgress',
  RepairStatus.qualityCheck: 'qualityCheck',
  RepairStatus.ready: 'ready',
  RepairStatus.delivered: 'delivered',
  RepairStatus.cancelled: 'cancelled',
  RepairStatus.returned: 'returned',
};

_RepairWorkItem _$RepairWorkItemFromJson(Map<String, dynamic> json) =>
    _RepairWorkItem(
      id: json['id'] as String,
      type: $enumDecode(_$RepairTypeEnumMap, json['type']),
      description: json['description'] as String,
      estimatedCostPaisa: (json['estimatedCostPaisa'] as num?)?.toInt(),
      actualCostPaisa: (json['actualCostPaisa'] as num?)?.toInt(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$RepairWorkItemToJson(_RepairWorkItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$RepairTypeEnumMap[instance.type]!,
      'description': instance.description,
      'estimatedCostPaisa': instance.estimatedCostPaisa,
      'actualCostPaisa': instance.actualCostPaisa,
      'isCompleted': instance.isCompleted,
      'completedBy': instance.completedBy,
      'completedAt': instance.completedAt?.toIso8601String(),
      'notes': instance.notes,
    };

const _$RepairTypeEnumMap = {
  RepairType.polishing: 'polishing',
  RepairType.cleaning: 'cleaning',
  RepairType.resizing: 'resizing',
  RepairType.soldering: 'soldering',
  RepairType.stoneSetting: 'stoneSetting',
  RepairType.stoneReplacement: 'stoneReplacement',
  RepairType.chainRepair: 'chainRepair',
  RepairType.claspReplacement: 'claspReplacement',
  RepairType.plating: 'plating',
  RepairType.engraving: 'engraving',
  RepairType.restoration: 'restoration',
  RepairType.customWork: 'customWork',
};

_RepairMaterial _$RepairMaterialFromJson(Map<String, dynamic> json) =>
    _RepairMaterial(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      costPaisa: (json['costPaisa'] as num).toInt(),
      supplier: json['supplier'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$RepairMaterialToJson(_RepairMaterial instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'costPaisa': instance.costPaisa,
      'supplier': instance.supplier,
      'notes': instance.notes,
    };

_JewelleryRepair _$JewelleryRepairFromJson(Map<String, dynamic> json) =>
    _JewelleryRepair(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      jobNumber: json['jobNumber'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      itemDescription: json['itemDescription'] as String,
      itemCategory: json['itemCategory'] as String?,
      metalType: json['metalType'] as String?,
      weightGrams: (json['weightGrams'] as num?)?.toDouble(),
      productId: json['productId'] as String?,
      workItems: (json['workItems'] as List<dynamic>)
          .map((e) => RepairWorkItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => RepairMaterial.fromJson(e as Map<String, dynamic>))
          .toList(),
      status:
          $enumDecodeNullable(_$RepairStatusEnumMap, json['status']) ??
          RepairStatus.pending,
      priority:
          $enumDecodeNullable(_$RepairPriorityEnumMap, json['priority']) ??
          RepairPriority.normal,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
          ?.map((e) => RepairStatusUpdate.fromJson(e as Map<String, dynamic>))
          .toList(),
      conditionPhotoUrls: (json['conditionPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      customerComplaint: json['customerComplaint'] as String?,
      damageAssessment: json['damageAssessment'] as String?,
      recommendedWork: json['recommendedWork'] as String?,
      estimatedCostPaisa: (json['estimatedCostPaisa'] as num?)?.toInt(),
      estimatedDays: (json['estimatedDays'] as num?)?.toInt(),
      estimatedCompletionDate: json['estimatedCompletionDate'] == null
          ? null
          : DateTime.parse(json['estimatedCompletionDate'] as String),
      actualCostPaisa: (json['actualCostPaisa'] as num?)?.toInt(),
      materialCostPaisa: (json['materialCostPaisa'] as num?)?.toInt(),
      laborCostPaisa: (json['laborCostPaisa'] as num?)?.toInt(),
      additionalChargesPaisa: (json['additionalChargesPaisa'] as num?)?.toInt(),
      additionalChargesNote: json['additionalChargesNote'] as String?,
      advanceReceivedPaisa:
          (json['advanceReceivedPaisa'] as num?)?.toInt() ?? 0,
      assignedTo: json['assignedTo'] as String?,
      assignedToName: json['assignedToName'] as String?,
      assignedAt: json['assignedAt'] == null
          ? null
          : DateTime.parse(json['assignedAt'] as String),
      receivedDate: DateTime.parse(json['receivedDate'] as String),
      promisedDate: json['promisedDate'] == null
          ? null
          : DateTime.parse(json['promisedDate'] as String),
      completedDate: json['completedDate'] == null
          ? null
          : DateTime.parse(json['completedDate'] as String),
      deliveredDate: json['deliveredDate'] == null
          ? null
          : DateTime.parse(json['deliveredDate'] as String),
      workStartedDate: json['workStartedDate'] == null
          ? null
          : DateTime.parse(json['workStartedDate'] as String),
      workCompletedDate: json['workCompletedDate'] == null
          ? null
          : DateTime.parse(json['workCompletedDate'] as String),
      actualWorkHours: (json['actualWorkHours'] as num?)?.toInt(),
      deliveredTo: json['deliveredTo'] as String?,
      deliveryNotes: json['deliveryNotes'] as String?,
      completionPhotoUrls: (json['completionPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      warrantyDays: (json['warrantyDays'] as num?)?.toInt() ?? 0,
      warrantyExpiryDate: json['warrantyExpiryDate'] == null
          ? null
          : DateTime.parse(json['warrantyExpiryDate'] as String),
      originalJobId: json['originalJobId'] as String?,
      isWarrantyClaim: json['isWarrantyClaim'] as bool? ?? false,
      customerRating: (json['customerRating'] as num?)?.toInt(),
      customerFeedback: json['customerFeedback'] as String?,
      invoiceId: json['invoiceId'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      updatedBy: json['updatedBy'] as String,
      synced: json['synced'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      pendingOperation: json['pendingOperation'] as String?,
    );

Map<String, dynamic> _$JewelleryRepairToJson(_JewelleryRepair instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'jobNumber': instance.jobNumber,
      'customerId': instance.customerId,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'customerEmail': instance.customerEmail,
      'itemDescription': instance.itemDescription,
      'itemCategory': instance.itemCategory,
      'metalType': instance.metalType,
      'weightGrams': instance.weightGrams,
      'productId': instance.productId,
      'workItems': instance.workItems,
      'materials': instance.materials,
      'status': _$RepairStatusEnumMap[instance.status]!,
      'priority': _$RepairPriorityEnumMap[instance.priority]!,
      'statusHistory': instance.statusHistory,
      'conditionPhotoUrls': instance.conditionPhotoUrls,
      'customerComplaint': instance.customerComplaint,
      'damageAssessment': instance.damageAssessment,
      'recommendedWork': instance.recommendedWork,
      'estimatedCostPaisa': instance.estimatedCostPaisa,
      'estimatedDays': instance.estimatedDays,
      'estimatedCompletionDate': instance.estimatedCompletionDate
          ?.toIso8601String(),
      'actualCostPaisa': instance.actualCostPaisa,
      'materialCostPaisa': instance.materialCostPaisa,
      'laborCostPaisa': instance.laborCostPaisa,
      'additionalChargesPaisa': instance.additionalChargesPaisa,
      'additionalChargesNote': instance.additionalChargesNote,
      'advanceReceivedPaisa': instance.advanceReceivedPaisa,
      'assignedTo': instance.assignedTo,
      'assignedToName': instance.assignedToName,
      'assignedAt': instance.assignedAt?.toIso8601String(),
      'receivedDate': instance.receivedDate.toIso8601String(),
      'promisedDate': instance.promisedDate?.toIso8601String(),
      'completedDate': instance.completedDate?.toIso8601String(),
      'deliveredDate': instance.deliveredDate?.toIso8601String(),
      'workStartedDate': instance.workStartedDate?.toIso8601String(),
      'workCompletedDate': instance.workCompletedDate?.toIso8601String(),
      'actualWorkHours': instance.actualWorkHours,
      'deliveredTo': instance.deliveredTo,
      'deliveryNotes': instance.deliveryNotes,
      'completionPhotoUrls': instance.completionPhotoUrls,
      'warrantyDays': instance.warrantyDays,
      'warrantyExpiryDate': instance.warrantyExpiryDate?.toIso8601String(),
      'originalJobId': instance.originalJobId,
      'isWarrantyClaim': instance.isWarrantyClaim,
      'customerRating': instance.customerRating,
      'customerFeedback': instance.customerFeedback,
      'invoiceId': instance.invoiceId,
      'isPaid': instance.isPaid,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'updatedBy': instance.updatedBy,
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
    };

const _$RepairPriorityEnumMap = {
  RepairPriority.low: 'low',
  RepairPriority.normal: 'normal',
  RepairPriority.high: 'high',
  RepairPriority.urgent: 'urgent',
};

_RepairStatistics _$RepairStatisticsFromJson(Map<String, dynamic> json) =>
    _RepairStatistics(
      totalJobs: (json['totalJobs'] as num?)?.toInt() ?? 0,
      pendingJobs: (json['pendingJobs'] as num?)?.toInt() ?? 0,
      inProgressJobs: (json['inProgressJobs'] as num?)?.toInt() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      deliveredJobs: (json['deliveredJobs'] as num?)?.toInt() ?? 0,
      overdueJobs: (json['overdueJobs'] as num?)?.toInt() ?? 0,
      warrantyClaims: (json['warrantyClaims'] as num?)?.toInt() ?? 0,
      averageRepairDays: (json['averageRepairDays'] as num?)?.toDouble() ?? 0,
      totalRevenuePaisa: (json['totalRevenuePaisa'] as num?)?.toInt() ?? 0,
      totalMaterialCostPaisa:
          (json['totalMaterialCostPaisa'] as num?)?.toInt() ?? 0,
      totalLaborCostPaisa: (json['totalLaborCostPaisa'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RepairStatisticsToJson(_RepairStatistics instance) =>
    <String, dynamic>{
      'totalJobs': instance.totalJobs,
      'pendingJobs': instance.pendingJobs,
      'inProgressJobs': instance.inProgressJobs,
      'completedJobs': instance.completedJobs,
      'deliveredJobs': instance.deliveredJobs,
      'overdueJobs': instance.overdueJobs,
      'warrantyClaims': instance.warrantyClaims,
      'averageRepairDays': instance.averageRepairDays,
      'totalRevenuePaisa': instance.totalRevenuePaisa,
      'totalMaterialCostPaisa': instance.totalMaterialCostPaisa,
      'totalLaborCostPaisa': instance.totalLaborCostPaisa,
    };
