// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gold_rate_alert_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoldRateAlert _$GoldRateAlertFromJson(Map<String, dynamic> json) =>
    _GoldRateAlert(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      userId: json['userId'] as String,
      metalType: $enumDecode(_$MetalTypeEnumMap, json['metalType']),
      thresholdRatePaisaPerGram: (json['thresholdRatePaisaPerGram'] as num)
          .toInt(),
      direction:
          $enumDecodeNullable(_$AlertDirectionEnumMap, json['direction']) ??
          AlertDirection.above,
      method:
          $enumDecodeNullable(_$NotificationMethodEnumMap, json['method']) ??
          NotificationMethod.push,
      note: json['note'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceHours: (json['recurrenceHours'] as num?)?.toInt(),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      status:
          $enumDecodeNullable(_$AlertStatusEnumMap, json['status']) ??
          AlertStatus.active,
      lastTriggeredAt: json['lastTriggeredAt'] == null
          ? null
          : DateTime.parse(json['lastTriggeredAt'] as String),
      triggeredRatePaisa: (json['triggeredRatePaisa'] as num?)?.toInt(),
      triggerCount: (json['triggerCount'] as num?)?.toInt() ?? 0,
      rateHistory: (json['rateHistory'] as List<dynamic>?)
          ?.map((e) => AlertRateCheck.fromJson(e as Map<String, dynamic>))
          .toList(),
      notificationHistory: (json['notificationHistory'] as List<dynamic>?)
          ?.map((e) => AlertNotificationLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      synced: json['synced'] as bool? ?? true,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      pendingOperation: json['pendingOperation'] as String?,
    );

Map<String, dynamic> _$GoldRateAlertToJson(_GoldRateAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'userId': instance.userId,
      'metalType': _$MetalTypeEnumMap[instance.metalType]!,
      'thresholdRatePaisaPerGram': instance.thresholdRatePaisaPerGram,
      'direction': _$AlertDirectionEnumMap[instance.direction]!,
      'method': _$NotificationMethodEnumMap[instance.method]!,
      'note': instance.note,
      'isRecurring': instance.isRecurring,
      'recurrenceHours': instance.recurrenceHours,
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'status': _$AlertStatusEnumMap[instance.status]!,
      'lastTriggeredAt': instance.lastTriggeredAt?.toIso8601String(),
      'triggeredRatePaisa': instance.triggeredRatePaisa,
      'triggerCount': instance.triggerCount,
      'rateHistory': instance.rateHistory,
      'notificationHistory': instance.notificationHistory,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'synced': instance.synced,
      'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
      'pendingOperation': instance.pendingOperation,
    };

const _$MetalTypeEnumMap = {
  MetalType.gold24k: 'gold24k',
  MetalType.gold22k: 'gold22k',
  MetalType.gold18k: 'gold18k',
  MetalType.gold14k: 'gold14k',
  MetalType.gold9k: 'gold9k',
  MetalType.silver: 'silver',
  MetalType.platinum: 'platinum',
  MetalType.diamond: 'diamond',
  MetalType.other: 'other',
};

const _$AlertDirectionEnumMap = {
  AlertDirection.above: 'above',
  AlertDirection.below: 'below',
  AlertDirection.both: 'both',
};

const _$NotificationMethodEnumMap = {
  NotificationMethod.push: 'push',
  NotificationMethod.email: 'email',
  NotificationMethod.sms: 'sms',
  NotificationMethod.whatsapp: 'whatsapp',
};

const _$AlertStatusEnumMap = {
  AlertStatus.active: 'active',
  AlertStatus.triggered: 'triggered',
  AlertStatus.paused: 'paused',
  AlertStatus.expired: 'expired',
};

_AlertRateCheck _$AlertRateCheckFromJson(Map<String, dynamic> json) =>
    _AlertRateCheck(
      checkedAt: DateTime.parse(json['checkedAt'] as String),
      ratePaisaPerGram: (json['ratePaisaPerGram'] as num).toInt(),
      wouldTrigger: json['wouldTrigger'] as bool,
    );

Map<String, dynamic> _$AlertRateCheckToJson(_AlertRateCheck instance) =>
    <String, dynamic>{
      'checkedAt': instance.checkedAt.toIso8601String(),
      'ratePaisaPerGram': instance.ratePaisaPerGram,
      'wouldTrigger': instance.wouldTrigger,
    };

_AlertNotificationLog _$AlertNotificationLogFromJson(
  Map<String, dynamic> json,
) => _AlertNotificationLog(
  sentAt: DateTime.parse(json['sentAt'] as String),
  method: $enumDecode(_$NotificationMethodEnumMap, json['method']),
  ratePaisaAtNotification: (json['ratePaisaAtNotification'] as num).toInt(),
  message: json['message'] as String,
  delivered: json['delivered'] as bool? ?? true,
  errorMessage: json['errorMessage'] as String?,
);

Map<String, dynamic> _$AlertNotificationLogToJson(
  _AlertNotificationLog instance,
) => <String, dynamic>{
  'sentAt': instance.sentAt.toIso8601String(),
  'method': _$NotificationMethodEnumMap[instance.method]!,
  'ratePaisaAtNotification': instance.ratePaisaAtNotification,
  'message': instance.message,
  'delivered': instance.delivered,
  'errorMessage': instance.errorMessage,
};

_AlertStatistics _$AlertStatisticsFromJson(Map<String, dynamic> json) =>
    _AlertStatistics(
      totalAlerts: (json['totalAlerts'] as num?)?.toInt() ?? 0,
      activeAlerts: (json['activeAlerts'] as num?)?.toInt() ?? 0,
      triggeredAlerts: (json['triggeredAlerts'] as num?)?.toInt() ?? 0,
      expiredAlerts: (json['expiredAlerts'] as num?)?.toInt() ?? 0,
      totalTriggers: (json['totalTriggers'] as num?)?.toInt() ?? 0,
      mostTriggeredAlert: json['mostTriggeredAlert'] == null
          ? null
          : GoldRateAlert.fromJson(
              json['mostTriggeredAlert'] as Map<String, dynamic>,
            ),
      recentlyTriggeredAlert: json['recentlyTriggeredAlert'] == null
          ? null
          : GoldRateAlert.fromJson(
              json['recentlyTriggeredAlert'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$AlertStatisticsToJson(_AlertStatistics instance) =>
    <String, dynamic>{
      'totalAlerts': instance.totalAlerts,
      'activeAlerts': instance.activeAlerts,
      'triggeredAlerts': instance.triggeredAlerts,
      'expiredAlerts': instance.expiredAlerts,
      'totalTriggers': instance.totalTriggers,
      'mostTriggeredAlert': instance.mostTriggeredAlert,
      'recentlyTriggeredAlert': instance.recentlyTriggeredAlert,
    };
