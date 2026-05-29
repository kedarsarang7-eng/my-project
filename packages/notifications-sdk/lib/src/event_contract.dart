// ============================================================================
// EventContract — canonical envelope for every UNS Event_Bus publish.
// ----------------------------------------------------------------------------
// Mirrors the JSON Schema at packages/notifications-sdk/event-contract.schema.json.
// The schema is the source of truth; this Dart class is a typed view over it.
// `parse(serialize(e))` MUST be structurally equivalent to `e` for every valid
// event (REQ 8.6, Property 4 in design.md).
// ============================================================================

/// Reliability tier requested by the Producer.
///
/// Maps to the `priority` enum in the Event_Contract schema. `critical` and
/// `high` ride the at_least_once delivery path; `normal` and `low` ride the
/// at_most_once_with_dedup path (REQ 9.1, 9.2).
enum EventPriority { critical, high, normal, low }

/// Top-level domain bucket for the event (Event_Contract `category` enum).
enum EventCategory {
  billing,
  orders,
  payments,
  inventory,
  users,
  system,
  delivery,
  reports,
}

/// Workspace app the event originated from (Event_Contract `source_app` enum).
enum SourceApp {
  dukanxDesktop,
  dukanxBackend,
  schoolAdminApp,
  schoolTeacherApp,
  schoolStudentApp,
  webhookConsumer,
}

/// Channel literal — schema enum for both envelope and recipient overrides.
enum NotificationChannel { inApp, push, sms, email, webhook }

/// Recipient role from the Phase 2 role inventory (closed enum in schema).
enum RecipientRole {
  superAdmin,
  admin,
  shopOwner,
  cashier,
  accountant,
  staff,
  deliveryAgent,
  vendor,
  customer,
  chef,
  kitchenStaff,
  waiter,
  schoolAdmin,
  teacher,
  student,
  parent,
  clinicDoctor,
  pharmacist,
  jewelleryArtisan,
  serviceTechnician,
  dcStaff,
  farmer,
  pumpAttendant,
}

/// Single resolved recipient inside the `recipients` array.
class Recipient {
  final String userId;
  final RecipientRole role;
  final List<NotificationChannel>? channels;
  final String? targetId;

  const Recipient({
    required this.userId,
    required this.role,
    this.channels,
    this.targetId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'role': _roleToWire(role),
    };
    if (channels != null) {
      map['channels'] = channels!.map(_channelToWire).toList();
    }
    if (targetId != null) {
      map['target_id'] = targetId;
    }
    return map;
  }

  factory Recipient.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    return Recipient(
      userId: json['user_id'] as String,
      role: _roleFromWire(json['role'] as String),
      channels: rawChannels is List
          ? rawChannels.map((c) => _channelFromWire(c as String)).toList()
          : null,
      targetId: json['target_id'] as String?,
    );
  }
}

/// Typed view over a single Event_Contract envelope.
///
/// Construction is intentionally permissive (does not re-validate the schema);
/// the SDK calls [SchemaValidator.validate] on the JSON form before publish so
/// schema violations surface with structured field errors (REQ 3.6, 8.7).
class EventContract {
  final String id;
  final String eventName;
  final EventCategory category;
  final String? subCategory;
  final EventPriority priority;
  final String actorId;
  final String? targetId;
  final List<Recipient> recipients;
  final Map<String, dynamic> payload;
  final List<NotificationChannel> channels;
  final String sourceModule;
  final SourceApp sourceApp;

  /// RFC 3339 / ISO 8601 with explicit UTC offset.
  /// Drives outbox replay ordering (REQ 8.8, 9.7).
  final String createdAt;

  final String dedupKey;
  final List<String>? dedupScopeFields;

  const EventContract({
    required this.id,
    required this.eventName,
    required this.category,
    this.subCategory,
    required this.priority,
    required this.actorId,
    this.targetId,
    required this.recipients,
    required this.payload,
    required this.channels,
    required this.sourceModule,
    required this.sourceApp,
    required this.createdAt,
    required this.dedupKey,
    this.dedupScopeFields,
  });

  /// Serialize to the wire shape that conforms to event-contract.schema.json.
  ///
  /// Optional fields that are null are omitted entirely (the schema rejects
  /// e.g. `"sub_category": null` because the type is plain string, not
  /// nullable). `target_id` is the documented exception — its schema type is
  /// `["string", "null"]` so we MUST emit `null` when it is unset to keep the
  /// round-trip property holding.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'event_name': eventName,
      'category': _categoryToWire(category),
      'priority': _priorityToWire(priority),
      'actor_id': actorId,
      'target_id': targetId, // schema permits null
      'recipients': recipients.map((r) => r.toJson()).toList(),
      'payload': payload,
      'channels': channels.map(_channelToWire).toList(),
      'source_module': sourceModule,
      'source_app': _sourceAppToWire(sourceApp),
      'created_at': createdAt,
      'dedup_key': dedupKey,
    };
    if (subCategory != null) {
      map['sub_category'] = subCategory;
    }
    if (dedupScopeFields != null) {
      map['dedup_scope_fields'] = List<String>.from(dedupScopeFields!);
    }
    return map;
  }

  factory EventContract.fromJson(Map<String, dynamic> json) {
    final rawRecipients = (json['recipients'] as List? ?? const []);
    final rawChannels = (json['channels'] as List? ?? const []);
    final rawScope = json['dedup_scope_fields'];
    return EventContract(
      id: json['id'] as String,
      eventName: json['event_name'] as String,
      category: _categoryFromWire(json['category'] as String),
      subCategory: json['sub_category'] as String?,
      priority: _priorityFromWire(json['priority'] as String),
      actorId: json['actor_id'] as String,
      targetId: json['target_id'] as String?,
      recipients: rawRecipients
          .map((r) => Recipient.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      channels:
          rawChannels.map((c) => _channelFromWire(c as String)).toList(),
      sourceModule: json['source_module'] as String,
      sourceApp: _sourceAppFromWire(json['source_app'] as String),
      createdAt: json['created_at'] as String,
      dedupKey: json['dedup_key'] as String,
      dedupScopeFields: rawScope is List
          ? rawScope.map((s) => s as String).toList()
          : null,
    );
  }
}

// ----------------------------------------------------------------------------
// Enum <-> wire-string conversions.
// Kept as private helpers so the wire format stays decoupled from Dart names.
// ----------------------------------------------------------------------------

String _priorityToWire(EventPriority p) {
  switch (p) {
    case EventPriority.critical:
      return 'critical';
    case EventPriority.high:
      return 'high';
    case EventPriority.normal:
      return 'normal';
    case EventPriority.low:
      return 'low';
  }
}

EventPriority _priorityFromWire(String s) {
  switch (s) {
    case 'critical':
      return EventPriority.critical;
    case 'high':
      return EventPriority.high;
    case 'normal':
      return EventPriority.normal;
    case 'low':
      return EventPriority.low;
  }
  throw FormatException('Unknown priority: $s');
}

String _categoryToWire(EventCategory c) {
  switch (c) {
    case EventCategory.billing:
      return 'billing';
    case EventCategory.orders:
      return 'orders';
    case EventCategory.payments:
      return 'payments';
    case EventCategory.inventory:
      return 'inventory';
    case EventCategory.users:
      return 'users';
    case EventCategory.system:
      return 'system';
    case EventCategory.delivery:
      return 'delivery';
    case EventCategory.reports:
      return 'reports';
  }
}

EventCategory _categoryFromWire(String s) {
  switch (s) {
    case 'billing':
      return EventCategory.billing;
    case 'orders':
      return EventCategory.orders;
    case 'payments':
      return EventCategory.payments;
    case 'inventory':
      return EventCategory.inventory;
    case 'users':
      return EventCategory.users;
    case 'system':
      return EventCategory.system;
    case 'delivery':
      return EventCategory.delivery;
    case 'reports':
      return EventCategory.reports;
  }
  throw FormatException('Unknown category: $s');
}

String _sourceAppToWire(SourceApp a) {
  switch (a) {
    case SourceApp.dukanxDesktop:
      return 'dukanx_desktop';
    case SourceApp.dukanxBackend:
      return 'dukanx_backend';
    case SourceApp.schoolAdminApp:
      return 'school_admin_app';
    case SourceApp.schoolTeacherApp:
      return 'school_teacher_app';
    case SourceApp.schoolStudentApp:
      return 'school_student_app';
    case SourceApp.webhookConsumer:
      return 'webhook_consumer';
  }
}

SourceApp _sourceAppFromWire(String s) {
  switch (s) {
    case 'dukanx_desktop':
      return SourceApp.dukanxDesktop;
    case 'dukanx_backend':
      return SourceApp.dukanxBackend;
    case 'school_admin_app':
      return SourceApp.schoolAdminApp;
    case 'school_teacher_app':
      return SourceApp.schoolTeacherApp;
    case 'school_student_app':
      return SourceApp.schoolStudentApp;
    case 'webhook_consumer':
      return SourceApp.webhookConsumer;
  }
  throw FormatException('Unknown source_app: $s');
}

String _channelToWire(NotificationChannel c) {
  switch (c) {
    case NotificationChannel.inApp:
      return 'in_app';
    case NotificationChannel.push:
      return 'push';
    case NotificationChannel.sms:
      return 'sms';
    case NotificationChannel.email:
      return 'email';
    case NotificationChannel.webhook:
      return 'webhook';
  }
}

NotificationChannel _channelFromWire(String s) {
  switch (s) {
    case 'in_app':
      return NotificationChannel.inApp;
    case 'push':
      return NotificationChannel.push;
    case 'sms':
      return NotificationChannel.sms;
    case 'email':
      return NotificationChannel.email;
    case 'webhook':
      return NotificationChannel.webhook;
  }
  throw FormatException('Unknown channel: $s');
}

String _roleToWire(RecipientRole r) {
  switch (r) {
    case RecipientRole.superAdmin:
      return 'super_admin';
    case RecipientRole.admin:
      return 'admin';
    case RecipientRole.shopOwner:
      return 'shop_owner';
    case RecipientRole.cashier:
      return 'cashier';
    case RecipientRole.accountant:
      return 'accountant';
    case RecipientRole.staff:
      return 'staff';
    case RecipientRole.deliveryAgent:
      return 'delivery_agent';
    case RecipientRole.vendor:
      return 'vendor';
    case RecipientRole.customer:
      return 'customer';
    case RecipientRole.chef:
      return 'chef';
    case RecipientRole.kitchenStaff:
      return 'kitchen_staff';
    case RecipientRole.waiter:
      return 'waiter';
    case RecipientRole.schoolAdmin:
      return 'school_admin';
    case RecipientRole.teacher:
      return 'teacher';
    case RecipientRole.student:
      return 'student';
    case RecipientRole.parent:
      return 'parent';
    case RecipientRole.clinicDoctor:
      return 'clinic_doctor';
    case RecipientRole.pharmacist:
      return 'pharmacist';
    case RecipientRole.jewelleryArtisan:
      return 'jewellery_artisan';
    case RecipientRole.serviceTechnician:
      return 'service_technician';
    case RecipientRole.dcStaff:
      return 'dc_staff';
    case RecipientRole.farmer:
      return 'farmer';
    case RecipientRole.pumpAttendant:
      return 'pump_attendant';
  }
}

RecipientRole _roleFromWire(String s) {
  switch (s) {
    case 'super_admin':
      return RecipientRole.superAdmin;
    case 'admin':
      return RecipientRole.admin;
    case 'shop_owner':
      return RecipientRole.shopOwner;
    case 'cashier':
      return RecipientRole.cashier;
    case 'accountant':
      return RecipientRole.accountant;
    case 'staff':
      return RecipientRole.staff;
    case 'delivery_agent':
      return RecipientRole.deliveryAgent;
    case 'vendor':
      return RecipientRole.vendor;
    case 'customer':
      return RecipientRole.customer;
    case 'chef':
      return RecipientRole.chef;
    case 'kitchen_staff':
      return RecipientRole.kitchenStaff;
    case 'waiter':
      return RecipientRole.waiter;
    case 'school_admin':
      return RecipientRole.schoolAdmin;
    case 'teacher':
      return RecipientRole.teacher;
    case 'student':
      return RecipientRole.student;
    case 'parent':
      return RecipientRole.parent;
    case 'clinic_doctor':
      return RecipientRole.clinicDoctor;
    case 'pharmacist':
      return RecipientRole.pharmacist;
    case 'jewellery_artisan':
      return RecipientRole.jewelleryArtisan;
    case 'service_technician':
      return RecipientRole.serviceTechnician;
    case 'dc_staff':
      return RecipientRole.dcStaff;
    case 'farmer':
      return RecipientRole.farmer;
    case 'pump_attendant':
      return RecipientRole.pumpAttendant;
  }
  throw FormatException('Unknown role: $s');
}
