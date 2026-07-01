import '../core/data/data_guard.dart';
import 'subscription_item.dart';

class Subscription {
  String id;
  String userId;
  String customerId;
  String planName;
  String? description;
  String billingCycle; // DAILY, WEEKLY, MONTHLY, YEARLY, CUSTOM
  int? customCycleDays;
  DateTime startDate;
  DateTime? endDate;
  DateTime? autoCancelDate;
  DateTime? lastBillingDate;
  DateTime nextBillingDate;
  double subtotal;
  double taxAmount;
  double discountAmount;
  double grandTotal;
  bool autoGenerateInvoice;
  bool autoSendEmail;
  bool autoSendWhatsapp;
  String status; // ACTIVE, CANCELLED, PAUSED, COMPLETED, PAST_DUE
  String? cancellationReason;
  int failedAttempts;
  bool isSynced;
  String? syncOperationId;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  int version;

  List<SubscriptionItem> items;

  Subscription({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.planName,
    this.description,
    this.billingCycle = 'MONTHLY',
    this.customCycleDays,
    required this.startDate,
    this.endDate,
    this.autoCancelDate,
    this.lastBillingDate,
    required this.nextBillingDate,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.grandTotal = 0.0,
    this.autoGenerateInvoice = true,
    this.autoSendEmail = false,
    this.autoSendWhatsapp = false,
    this.status = 'ACTIVE',
    this.cancellationReason,
    this.failedAttempts = 0,
    this.isSynced = false,
    this.syncOperationId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.version = 1,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'customerId': customerId,
    'planName': planName,
    'description': description,
    'billingCycle': billingCycle,
    'customCycleDays': customCycleDays,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'autoCancelDate': autoCancelDate?.toIso8601String(),
    'lastBillingDate': lastBillingDate?.toIso8601String(),
    'nextBillingDate': nextBillingDate.toIso8601String(),
    'subtotal': subtotal,
    'taxAmount': taxAmount,
    'discountAmount': discountAmount,
    'grandTotal': grandTotal,
    'autoGenerateInvoice': autoGenerateInvoice,
    'autoSendEmail': autoSendEmail,
    'autoSendWhatsapp': autoSendWhatsapp,
    'status': status,
    'cancellationReason': cancellationReason,
    'failedAttempts': failedAttempts,
    'isSynced': isSynced,
    'syncOperationId': syncOperationId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'version': version,
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory Subscription.fromMap(
    Map<String, dynamic> m, {
    List<SubscriptionItem>? items,
  }) {
    final parsedItems =
        items ??
        (m['items'] as List<dynamic>?)
            ?.map((i) => SubscriptionItem.fromMap(i as Map<String, dynamic>))
            .toList() ??
        [];

    return Subscription(
      id: DataGuard.safeString(m['id']),
      userId: DataGuard.safeString(m['userId']),
      customerId: DataGuard.safeString(m['customerId']),
      planName: DataGuard.safeString(m['planName']),
      description: m['description']?.toString(),
      billingCycle: DataGuard.safeString(
        m['billingCycle'],
        fallback: 'MONTHLY',
      ),
      customCycleDays: m['customCycleDays'] != null
          ? DataGuard.safeInt(m['customCycleDays'])
          : null,
      startDate: DataGuard.safeDate(m['startDate']) ?? DateTime.now(),
      endDate: DataGuard.safeDate(m['endDate']),
      autoCancelDate: DataGuard.safeDate(m['autoCancelDate']),
      lastBillingDate: DataGuard.safeDate(m['lastBillingDate']),
      nextBillingDate:
          DataGuard.safeDate(m['nextBillingDate']) ?? DateTime.now(),
      subtotal: DataGuard.safeDouble(m['subtotal']),
      taxAmount: DataGuard.safeDouble(m['taxAmount']),
      discountAmount: DataGuard.safeDouble(m['discountAmount']),
      grandTotal: DataGuard.safeDouble(m['grandTotal']),
      autoGenerateInvoice: DataGuard.safeBool(
        m['autoGenerateInvoice'],
        fallback: true,
      ),
      autoSendEmail: DataGuard.safeBool(m['autoSendEmail']),
      autoSendWhatsapp: DataGuard.safeBool(m['autoSendWhatsapp']),
      status: DataGuard.safeString(m['status'], fallback: 'ACTIVE'),
      cancellationReason: m['cancellationReason']?.toString(),
      failedAttempts: DataGuard.safeInt(m['failedAttempts']),
      isSynced: DataGuard.safeBool(m['isSynced']),
      syncOperationId: m['syncOperationId']?.toString(),
      createdAt: DataGuard.safeDate(m['createdAt']) ?? DateTime.now(),
      updatedAt: DataGuard.safeDate(m['updatedAt']) ?? DateTime.now(),
      deletedAt: DataGuard.safeDate(m['deletedAt']),
      version: DataGuard.safeInt(m['version'], fallback: 1),
      items: parsedItems,
    );
  }
}
