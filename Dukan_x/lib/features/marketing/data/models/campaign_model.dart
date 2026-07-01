/// Campaign Status
enum CampaignStatus { draft, scheduled, running, completed, cancelled, failed }

/// Campaign Type
enum CampaignType { whatsapp, sms, both }

/// Target Segment
enum TargetSegment { all, highValue, inactive, overdue, custom }

/// Marketing Campaign Model
class CampaignModel {
  final String id;
  final String userId;
  final String name;
  final CampaignType type;
  final String? templateId;
  final TargetSegment targetSegment;
  final String? customFilterJson;
  final String message;
  final String? imageUrl;
  final DateTime? scheduledAt;
  final bool isRecurring;
  final String? recurringPattern;
  final CampaignStatus status;
  final int totalRecipients;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isSynced;
  final String? syncOperationId;

  const CampaignModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.templateId,
    required this.targetSegment,
    this.customFilterJson,
    required this.message,
    this.imageUrl,
    this.scheduledAt,
    this.isRecurring = false,
    this.recurringPattern,
    this.status = CampaignStatus.draft,
    this.totalRecipients = 0,
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.failedCount = 0,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.isSynced = false,
    this.syncOperationId,
  });

  CampaignModel copyWith({
    String? id,
    String? userId,
    String? name,
    CampaignType? type,
    String? templateId,
    TargetSegment? targetSegment,
    String? customFilterJson,
    String? message,
    String? imageUrl,
    DateTime? scheduledAt,
    bool? isRecurring,
    String? recurringPattern,
    CampaignStatus? status,
    int? totalRecipients,
    int? sentCount,
    int? deliveredCount,
    int? failedCount,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isSynced,
    String? syncOperationId,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      templateId: templateId ?? this.templateId,
      targetSegment: targetSegment ?? this.targetSegment,
      customFilterJson: customFilterJson ?? this.customFilterJson,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      status: status ?? this.status,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      sentCount: sentCount ?? this.sentCount,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      failedCount: failedCount ?? this.failedCount,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      isSynced: isSynced ?? this.isSynced,
      syncOperationId: syncOperationId ?? this.syncOperationId,
    );
  }
}

/// Extension for entity mapping
extension CampaignModelX on CampaignModel {
  /// Create from database entity
  static CampaignModel fromEntity(dynamic entity) {
    return CampaignModel(
      id: entity.id as String,
      userId: entity.userId as String,
      name: entity.name as String,
      type: _parseType(entity.type as String),
      templateId: entity.templateId as String?,
      targetSegment: _parseSegment(entity.targetSegment as String),
      customFilterJson: entity.customFilterJson as String?,
      message: entity.message as String,
      imageUrl: entity.imageUrl as String?,
      scheduledAt: entity.scheduledAt as DateTime?,
      isRecurring: entity.isRecurring as bool,
      recurringPattern: entity.recurringPattern as String?,
      status: _parseStatus(entity.status as String),
      totalRecipients: entity.totalRecipients as int,
      sentCount: entity.sentCount as int,
      deliveredCount: entity.deliveredCount as int,
      failedCount: entity.failedCount as int,
      createdAt: entity.createdAt as DateTime,
      startedAt: entity.startedAt as DateTime?,
      completedAt: entity.completedAt as DateTime?,
      isSynced: entity.isSynced as bool,
      syncOperationId: entity.syncOperationId as String?,
    );
  }

  static CampaignType _parseType(String type) {
    switch (type.toUpperCase()) {
      case 'SMS':
        return CampaignType.sms;
      case 'BOTH':
        return CampaignType.both;
      default:
        return CampaignType.whatsapp;
    }
  }

  static TargetSegment _parseSegment(String segment) {
    switch (segment.toUpperCase()) {
      case 'HIGH_VALUE':
        return TargetSegment.highValue;
      case 'INACTIVE':
        return TargetSegment.inactive;
      case 'OVERDUE':
        return TargetSegment.overdue;
      case 'CUSTOM':
        return TargetSegment.custom;
      default:
        return TargetSegment.all;
    }
  }

  static CampaignStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return CampaignStatus.scheduled;
      case 'RUNNING':
        return CampaignStatus.running;
      case 'COMPLETED':
        return CampaignStatus.completed;
      case 'CANCELLED':
        return CampaignStatus.cancelled;
      case 'FAILED':
        return CampaignStatus.failed;
      default:
        return CampaignStatus.draft;
    }
  }
}
