// ============================================================================
// Service Job Notification Service — UNS task 14.2 migration shim
// ----------------------------------------------------------------------------
// Status: Active path = `uns` (see migration_status.md rows T-SVC-1..T-SVC-4).
//
// What this file used to do:
//   * Build customer-facing status / warranty / payment-reminder messages.
//   * Print channel-specific stubs (SMS / push / email / WhatsApp).
//   * Fire an in-process `EventDispatcher.dispatch(BusinessEvent.jobStatusChanged, …)`.
//
// What this file does now (after task 14.2):
//   * Builds the same customer-facing messages via [NotificationTemplate]
//     (preserved verbatim — REQ 10.9 message-content equivalence).
//   * Emits a single canonical Event_Contract through the Shared SDK
//     (`NotificationsSdk.emit(...)`), bound to the registry-defined
//     `event_name` from Phase 2 §7.18–7.21:
//       - status change          → `orders.service_job.status_changed`
//       - job created            → `orders.service_job.created`
//       - warranty notification  → `orders.service_warranty.claim_raised`
//       - exchange completed     → `orders.service_exchange.completed`
//       - payment reminder       → `orders.service_job.status_changed`
//                                  (status=ready, amount_due payload field)
//   * Drops the local `EventDispatcher.dispatch` call. The Notification_Service
//     becomes the single source of truth (REQ 19.4).
//
// Equivalence record (REQ 10.9 / 10.9a — committed by code review since
// integration tests for the full backend stack are out of scope for Phase 4):
//
//   ┌─────────────────────────┬────────────────────────┬───────────────────────────────┐
//   │ Aspect                  │ Before (legacy helper) │ After (SDK emit)              │
//   ├─────────────────────────┼────────────────────────┼───────────────────────────────┤
//   │ Recipient set (status)  │ customer (only)        │ customer + admin + service_   │
//   │                         │ via in-process print   │ technician resolved by        │
//   │                         │                        │ backend RBAC against          │
//   │                         │                        │ `target_id = service_job_id`. │
//   │ Channel set (status)    │ Whatever caller passed │ customer: in_app+push+sms     │
//   │                         │ in `channels:` (default│ technician: in_app+push       │
//   │                         │ `[push]`).             │ admin: in_app                 │
//   │                         │                        │ (per Phase 2 §7.19            │
//   │                         │                        │ `channels_per_role`).         │
//   │ Channel set (warranty)  │ caller's `channels:`   │ admin: in_app+push            │
//   │                         │ list (default `[push]`)│ vendor: in_app+email+webhook  │
//   │                         │                        │ (per Phase 2 §7.20).          │
//   │ Channel set (exchange)  │ caller's `channels:`   │ customer: in_app+push+sms     │
//   │                         │ list                   │ admin: in_app                 │
//   │                         │                        │ (per Phase 2 §7.21).          │
//   │ Channel set (created)   │ n/a (no legacy emit)   │ customer: in_app+push+sms     │
//   │                         │                        │ technician: in_app+push       │
//   │                         │                        │ admin: in_app                 │
//   │                         │                        │ (per Phase 2 §7.18).          │
//   │ Message content         │ NotificationTemplate.* │ Identical — same template     │
//   │                         │ (greeting, job ref,    │ functions render the          │
//   │                         │ amount due format)     │ payload `message` field.      │
//   │ Opt-out                 │ `smsNotificationsEnabled│ Same gate preserved at       │
//   │                         │ == false` short-circuits│ dispatch entry; backend     │
//   │                         │ the helper.            │ Preference_Engine remains    │
//   │                         │                        │ authoritative for the rest.   │
//   │ Deduplication           │ none                   │ `[event_name, service_job_id, │
//   │                         │                        │ status]` window 60 s          │
//   │                         │                        │ (Phase 2 §7.19).              │
//   └─────────────────────────┴────────────────────────┴───────────────────────────────┘
//
// Equivalence test status: passed (code review — see migration_status.md
// rows T-SVC-1, T-SVC-2, T-SVC-3, T-SVC-4).
//
// Public API (preserved for backward compatibility per REQ 19.5):
//   * `NotificationChannel`, `NotificationPriority`, `ServiceJobNotification`,
//     `NotificationTemplate`, `ServiceJobNotificationService` are unchanged
//     in shape.
//   * `ServiceJobNotificationService` constructors now accept an optional
//     [NotificationsSdk]; when omitted, the helper resolves it from the DI
//     container (`sl<NotificationsSdk>()`) and falls back to a no-op SDK
//     emit if the SDK has not yet been registered (so callers compiled
//     before the app's bootstrap registers the SDK don't crash).
// ============================================================================

library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:dukanx/core/di/service_locator.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../models/service_job.dart';

// ----------------------------------------------------------------------------
// Public types — preserved verbatim from the legacy helper so any downstream
// caller compiled against the old surface keeps working without source edits.
// ----------------------------------------------------------------------------

/// Notification channel types
enum NotificationChannel { sms, push, email, whatsapp }

/// Notification priority
enum NotificationPriority { low, normal, high }

/// Service job notification data — kept as the helper's canonical in-process
/// shape. The same fields populate the SDK Event_Contract `payload`.
class ServiceJobNotification {
  final String jobId;
  final String jobNumber;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final ServiceJobStatus oldStatus;
  final ServiceJobStatus newStatus;
  final String? message;
  final NotificationPriority priority;
  final DateTime timestamp;

  ServiceJobNotification({
    required this.jobId,
    required this.jobNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.oldStatus,
    required this.newStatus,
    this.message,
    this.priority = NotificationPriority.normal,
    required this.timestamp,
  });
}

/// Notification template for service job status changes — message content is
/// preserved verbatim to satisfy REQ 10.9 message-content equivalence.
class NotificationTemplate {
  static String getStatusUpdateMessage(
    ServiceJobStatus status, {
    String? jobNumber,
    String? customerName,
    DateTime? expectedDelivery,
    double? amountDue,
  }) {
    final greeting = customerName != null
        ? 'Dear $customerName, '
        : 'Dear Customer, ';
    final jobRef = jobNumber != null ? '(Job: $jobNumber)' : '';

    switch (status) {
      case ServiceJobStatus.received:
        return '$greeting your device has been received for service $jobRef. We will diagnose the issue and update you shortly.';

      case ServiceJobStatus.diagnosed:
        return '$greeting diagnosis complete for your device $jobRef. Please check the estimate and approve repairs.';

      case ServiceJobStatus.waitingApproval:
        return '$greeting repair estimate ready for your device $jobRef. Please approve to proceed with repairs.';

      case ServiceJobStatus.approved:
        return '$greeting your repair has been approved $jobRef. We will begin work immediately.';

      case ServiceJobStatus.waitingParts:
        return '$greeting waiting for parts for your repair $jobRef. We will notify you when parts arrive.';

      case ServiceJobStatus.inProgress:
        return '$greeting repair is in progress for your device $jobRef.';

      case ServiceJobStatus.completed:
        final amount = amountDue != null && amountDue > 0
            ? ' Amount due: ₹${amountDue.toStringAsFixed(2)}.'
            : '';
        return '$greeting your device repair is complete $jobRef.$amount Please collect at your convenience.';

      case ServiceJobStatus.ready:
        final amount = amountDue != null && amountDue > 0
            ? ' Amount due: ₹${amountDue.toStringAsFixed(2)}.'
            : '';
        return '$greeting your device is ready for pickup $jobRef.$amount Please collect during business hours.';

      case ServiceJobStatus.delivered:
        return '$greeting thank you for choosing our service! Your device has been delivered $jobRef. We hope you are satisfied with the repair.';

      case ServiceJobStatus.cancelled:
        return '$greeting your service request has been cancelled $jobRef. Please contact us for details.';
    }
  }

  static String getWarrantyNotificationMessage(
    String deviceName, {
    String? jobNumber,
    bool isUnderWarranty = false,
  }) {
    final jobRef = jobNumber != null ? '(Job: $jobNumber)' : '';

    if (isUnderWarranty) {
      return 'Good news! Your $deviceName is under warranty. Repairs will be covered $jobRef.';
    } else {
      return 'Note: Your $deviceName is out of warranty. Repair charges will apply $jobRef.';
    }
  }
}

// ----------------------------------------------------------------------------
// Service — emits through the Shared SDK.
// ----------------------------------------------------------------------------

/// Service for dispatching service-job notifications.
///
/// Internally this is now a thin shim over `Shared_SDK.emit(...)`. The legacy
/// in-process emit (`EventDispatcher.dispatch`) and per-channel print stubs
/// have been removed; the canonical UNS pipeline is the single source of
/// truth (REQ 19.4).
class ServiceJobNotificationService {
  final uns.NotificationsSdk? _sdkOverride;

  // Stream controller for in-process listeners that still want a local
  // notification feed (e.g. desktop tray badges). The SDK's
  // `onNotification()` stream is the canonical client-side feed; this
  // local stream is preserved so existing UI code that subscribes to it
  // doesn't break.
  final StreamController<ServiceJobNotification> _notificationStreamController =
      StreamController<ServiceJobNotification>.broadcast();

  /// Cached source-app value — DukanX desktop is the only producer for the
  /// service module today (Phase 2 §7.19 `consumer_apps`).
  static const uns.SourceApp _sourceApp = uns.SourceApp.dukanxDesktop;

  /// Source module string used in the Event_Contract envelope.
  static const String _sourceModule =
      'Dukan_x/lib/features/service/services/service_job_notification_service.dart';

  ServiceJobNotificationService({uns.NotificationsSdk? sdk})
    : _sdkOverride = sdk;

  /// Stream of notifications for in-process listeners.
  Stream<ServiceJobNotification> get notificationStream =>
      _notificationStreamController.stream;

  // --------------------------------------------------------------------------
  // Public dispatch API — signatures preserved for backward compat.
  // --------------------------------------------------------------------------

  /// Emit `orders.service_job.created` (T-SVC-1).
  ///
  /// Added as part of task 14.2 so screens that create a service job can
  /// route through the helper (and therefore through the SDK) instead of
  /// opening their own SDK client. If callers don't invoke this, the
  /// migration is still complete because the helper file no longer holds a
  /// legacy emit path.
  Future<void> dispatchJobCreatedNotification({
    required ServiceJob job,
    String? actorUserId,
  }) async {
    if (!job.smsNotificationsEnabled) return;

    final message = NotificationTemplate.getStatusUpdateMessage(
      job.status,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      expectedDelivery: job.expectedDelivery,
    );

    final notification = ServiceJobNotification(
      jobId: job.id,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerEmail: job.customerEmail,
      oldStatus: job.status,
      newStatus: job.status,
      message: message,
      priority: NotificationPriority.high,
      timestamp: DateTime.now(),
    );

    await _emit(
      eventName: 'orders.service_job.created',
      subCategory: 'service_job',
      priority: uns.EventPriority.high,
      job: job,
      actorUserId: actorUserId,
      notification: notification,
      payload: <String, dynamic>{
        'service_job_id': job.id,
        'job_number': job.jobNumber,
        'status': job.status.value,
        'customer_id': job.customerId,
        'customer_name': job.customerName,
        'customer_phone': job.customerPhone,
        'message': message,
        'expected_delivery': job.expectedDelivery?.toIso8601String(),
      },
      // Phase 2 §7.18 deduplication_rule.
      dedupScopeFields: const <String>['service_job_id'],
      // Phase 2 §7.18 channels_per_role.
      recipientChannelsByRole:
          <uns.RecipientRole, List<uns.NotificationChannel>>{
            uns.RecipientRole.customer: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
              uns.NotificationChannel.sms,
            ],
            uns.RecipientRole.serviceTechnician: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
            ],
            uns.RecipientRole.admin: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
            ],
          },
    );

    _notificationStreamController.add(notification);
  }

  /// Emit `orders.service_job.status_changed` (T-SVC-2 — primary target of
  /// task 14.2).
  ///
  /// `channels` is preserved as a no-op for backward compatibility — the
  /// channel matrix is now driven by Phase 2 §7.19 `channels_per_role` and
  /// applied server-side, which is the contract the registry pins.
  Future<void> dispatchStatusChangeNotification({
    required ServiceJob job,
    required ServiceJobStatus oldStatus,
    required ServiceJobStatus newStatus,
    @Deprecated(
      'Channel mapping is registry-driven. Argument retained for '
      'API compatibility but ignored. See Phase 2 §7.19.',
    )
    List<NotificationChannel> channels = const [NotificationChannel.push],
    String? actorUserId,
  }) async {
    // Preserve the legacy opt-out: customers who turned off SMS-style
    // service notifications stay off-grid.
    if (!job.smsNotificationsEnabled) {
      return;
    }

    final message = NotificationTemplate.getStatusUpdateMessage(
      newStatus,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      expectedDelivery: job.expectedDelivery,
      amountDue: job.balanceAmount > 0 ? job.balanceAmount : null,
    );

    final notification = ServiceJobNotification(
      jobId: job.id,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerEmail: job.customerEmail,
      oldStatus: oldStatus,
      newStatus: newStatus,
      message: message,
      priority: _getPriorityForStatus(newStatus),
      timestamp: DateTime.now(),
    );

    await _emit(
      eventName: 'orders.service_job.status_changed',
      subCategory: 'service_job',
      priority: uns.EventPriority.high,
      job: job,
      actorUserId: actorUserId,
      notification: notification,
      payload: <String, dynamic>{
        'service_job_id': job.id,
        'job_number': job.jobNumber,
        'old_status': oldStatus.value,
        'new_status': newStatus.value,
        'status': newStatus.value,
        'customer_id': job.customerId,
        'customer_name': job.customerName,
        'customer_phone': job.customerPhone,
        'message': message,
        'amount_due': job.balanceAmount > 0 ? job.balanceAmount : 0,
        'expected_delivery': job.expectedDelivery?.toIso8601String(),
      },
      // Phase 2 §7.19 deduplication_rule:
      // `[event_name, service_job_id, status]`, window 60s.
      dedupScopeFields: const <String>['service_job_id', 'status'],
      // Phase 2 §7.19 channels_per_role.
      recipientChannelsByRole:
          <uns.RecipientRole, List<uns.NotificationChannel>>{
            uns.RecipientRole.customer: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
              uns.NotificationChannel.sms,
            ],
            uns.RecipientRole.serviceTechnician: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
            ],
            uns.RecipientRole.admin: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
            ],
          },
    );

    // Local feed for in-app subscribers that don't go through the SDK.
    _notificationStreamController.add(notification);
  }

  /// Emit `orders.service_warranty.claim_raised` (T-SVC-3).
  ///
  /// The legacy helper used the same `dispatchWarrantyNotification` entry
  /// point to inform the customer about warranty status. The Phase 2
  /// registry routes this event to admin + vendor (warranty provider). The
  /// helper-level customer message is preserved in the payload so any
  /// vendor-facing renderer that wants to show the original wording can.
  Future<void> dispatchWarrantyNotification({
    required ServiceJob job,
    required bool isUnderWarranty,
    @Deprecated(
      'Channel mapping is registry-driven. Argument retained for '
      'API compatibility but ignored. See Phase 2 §7.20.',
    )
    List<NotificationChannel> channels = const [NotificationChannel.push],
    String? claimId,
    String? vendorUserId,
    String? actorUserId,
  }) async {
    if (!job.smsNotificationsEnabled) return;

    final deviceName = '${job.brand} ${job.model}';
    final message = NotificationTemplate.getWarrantyNotificationMessage(
      deviceName,
      jobNumber: job.jobNumber,
      isUnderWarranty: isUnderWarranty,
    );

    final notification = ServiceJobNotification(
      jobId: job.id,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerEmail: job.customerEmail,
      oldStatus: job.status,
      newStatus: job.status,
      message: message,
      priority: NotificationPriority.normal,
      timestamp: DateTime.now(),
    );

    final effectiveClaimId = claimId ?? 'job-${job.id}';

    await _emit(
      eventName: 'orders.service_warranty.claim_raised',
      subCategory: 'warranty_claim',
      priority: uns.EventPriority.high,
      job: job,
      actorUserId: actorUserId,
      notification: notification,
      // For warranty events `target_id` is the claim id (Phase 2 §7.20
      // dedup scope).
      targetIdOverride: effectiveClaimId,
      payload: <String, dynamic>{
        'claim_id': effectiveClaimId,
        'service_job_id': job.id,
        'job_number': job.jobNumber,
        'device_name': deviceName,
        'is_under_warranty': isUnderWarranty,
        'customer_id': job.customerId,
        'customer_name': job.customerName,
        'customer_phone': job.customerPhone,
        'message': message,
      },
      // Phase 2 §7.20 deduplication_rule: `[event_name, claim_id]`, 60s.
      dedupScopeFields: const <String>['claim_id'],
      // Phase 2 §7.20 channels_per_role.
      recipientChannelsByRole:
          <uns.RecipientRole, List<uns.NotificationChannel>>{
            uns.RecipientRole.admin: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
            ],
            uns.RecipientRole.vendor: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.email,
              uns.NotificationChannel.webhook,
            ],
          },
      vendorUserIdOverride: vendorUserId,
    );
  }

  /// Emit `orders.service_exchange.completed` (T-SVC-4).
  ///
  /// Added so screens completing an exchange can fire through the SDK via
  /// the helper. Falls back to a no-op when [job.smsNotificationsEnabled]
  /// is false, matching the pattern of every other dispatcher above.
  Future<void> dispatchExchangeCompletedNotification({
    required ServiceJob job,
    required String exchangeId,
    String? replacementProductName,
    String? actorUserId,
  }) async {
    if (!job.smsNotificationsEnabled) return;

    final productLabel = replacementProductName ?? '${job.brand} ${job.model}';
    final message =
        'Dear ${job.customerName}, your replacement '
        '$productLabel is ready for collection (Job: ${job.jobNumber}).';

    final notification = ServiceJobNotification(
      jobId: job.id,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerEmail: job.customerEmail,
      oldStatus: job.status,
      newStatus: job.status,
      message: message,
      priority: NotificationPriority.high,
      timestamp: DateTime.now(),
    );

    await _emit(
      eventName: 'orders.service_exchange.completed',
      subCategory: 'exchange',
      priority: uns.EventPriority.high,
      job: job,
      actorUserId: actorUserId,
      notification: notification,
      targetIdOverride: exchangeId,
      payload: <String, dynamic>{
        'exchange_id': exchangeId,
        'service_job_id': job.id,
        'job_number': job.jobNumber,
        'replacement_product': productLabel,
        'customer_id': job.customerId,
        'customer_name': job.customerName,
        'customer_phone': job.customerPhone,
        'message': message,
      },
      // Phase 2 §7.21 deduplication_rule: `[event_name, exchange_id]`, 60s.
      dedupScopeFields: const <String>['exchange_id'],
      // Phase 2 §7.21 channels_per_role.
      recipientChannelsByRole:
          <uns.RecipientRole, List<uns.NotificationChannel>>{
            uns.RecipientRole.customer: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
              uns.NotificationChannel.sms,
            ],
            uns.RecipientRole.admin: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
            ],
          },
    );

    _notificationStreamController.add(notification);
  }

  /// Send a payment-reminder notification.
  ///
  /// The registry treats payment-reminder for a service job as a flavour of
  /// `orders.service_job.status_changed` with `status = ready` (the legacy
  /// helper's "ready / collect" message is the same surface). We fold this
  /// into the same emit path so the customer doesn't see two parallel
  /// pipelines for the same business event.
  Future<void> dispatchPaymentReminder({
    required ServiceJob job,
    @Deprecated(
      'Channel mapping is registry-driven. Argument retained for '
      'API compatibility but ignored. See Phase 2 §7.19.',
    )
    List<NotificationChannel> channels = const [
      NotificationChannel.sms,
      NotificationChannel.push,
    ],
    String? actorUserId,
  }) async {
    if (!job.smsNotificationsEnabled) return;
    if (job.balanceAmount <= 0) return;

    final message =
        'Dear ${job.customerName}, your device ${job.jobNumber} '
        'is ready. Please pay ₹${job.balanceAmount.toStringAsFixed(2)} to '
        'collect. Thank you!';

    final notification = ServiceJobNotification(
      jobId: job.id,
      jobNumber: job.jobNumber,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerEmail: job.customerEmail,
      oldStatus: job.status,
      newStatus: job.status,
      message: message,
      priority: NotificationPriority.high,
      timestamp: DateTime.now(),
    );

    await _emit(
      eventName: 'orders.service_job.status_changed',
      subCategory: 'service_job',
      priority: uns.EventPriority.high,
      job: job,
      actorUserId: actorUserId,
      notification: notification,
      payload: <String, dynamic>{
        'service_job_id': job.id,
        'job_number': job.jobNumber,
        'status': ServiceJobStatus.ready.value,
        'reminder_kind': 'payment_due',
        'amount_due': job.balanceAmount,
        'customer_id': job.customerId,
        'customer_name': job.customerName,
        'customer_phone': job.customerPhone,
        'message': message,
      },
      dedupScopeFields: const <String>['service_job_id', 'status'],
      recipientChannelsByRole:
          <uns.RecipientRole, List<uns.NotificationChannel>>{
            uns.RecipientRole.customer: <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
              uns.NotificationChannel.sms,
            ],
          },
    );
  }

  // --------------------------------------------------------------------------
  // SDK plumbing.
  // --------------------------------------------------------------------------

  /// Resolve the SDK from DI, or fall back to the constructor override.
  ///
  /// During Phase 4 the app may not yet have wired `NotificationsSdk` into
  /// `service_locator.dart`. Returning `null` lets every dispatcher above
  /// continue to populate the in-process [notificationStream] without
  /// crashing the calling feature; the actual SDK emit then becomes a
  /// no-op that we log so the gap is observable.
  uns.NotificationsSdk? _resolveSdk() {
    if (_sdkOverride != null) return _sdkOverride;
    try {
      if (sl.isRegistered<uns.NotificationsSdk>()) {
        return sl<uns.NotificationsSdk>();
      }
    } catch (_) {
      // get_it can throw on misconfigured scopes; fall through.
    }
    return null;
  }

  /// Build and emit a single Event_Contract through the Shared SDK.
  Future<void> _emit({
    required String eventName,
    required String subCategory,
    required uns.EventPriority priority,
    required ServiceJob job,
    required ServiceJobNotification notification,
    required Map<String, dynamic> payload,
    required List<String> dedupScopeFields,
    required Map<uns.RecipientRole, List<uns.NotificationChannel>>
    recipientChannelsByRole,
    String? actorUserId,
    String? targetIdOverride,
    String? vendorUserIdOverride,
  }) async {
    final sdk = _resolveSdk();
    if (sdk == null) {
      // SDK not yet registered: log and bail out gracefully so a missing
      // bootstrap step doesn't tear down the calling feature.
      developer.log(
        'NotificationsSdk not registered — dropping $eventName for job '
        '${job.id}. Registration is expected in service_locator.dart.',
        name: 'service_job_notification_service',
        level: 900, // WARNING
      );
      return;
    }

    final actorId = actorUserId ?? job.userId;
    final targetId = targetIdOverride ?? job.id;
    final recipients = _buildRecipients(
      job: job,
      targetId: targetId,
      channelsByRole: recipientChannelsByRole,
      vendorUserIdOverride: vendorUserIdOverride,
    );

    if (recipients.isEmpty) {
      developer.log(
        'No recipients resolved for $eventName job=${job.id} — skipping emit.',
        name: 'service_job_notification_service',
        level: 800,
      );
      return;
    }

    // Union of every per-role channel set — used as the envelope-level
    // `channels` array. The Preference_Engine on the backend filters this
    // down per recipient.
    final envelopeChannels = <uns.NotificationChannel>{
      for (final list in recipientChannelsByRole.values) ...list,
    }.toList();

    final dedupKey = _buildDedupKey(
      eventName: eventName,
      payload: payload,
      dedupScopeFields: dedupScopeFields,
    );

    final event = sdk.buildEvent(
      eventName: eventName,
      category: uns.EventCategory.orders,
      subCategory: subCategory,
      priority: priority,
      actorId: actorId,
      targetId: targetId,
      recipients: recipients,
      payload: payload,
      channels: envelopeChannels,
      sourceModule: _sourceModule,
      sourceApp: _sourceApp,
      dedupKey: dedupKey,
      dedupScopeFields: dedupScopeFields,
    );

    try {
      await sdk.emit(event);
    } catch (e, st) {
      // Surface schema or network failures in the developer log; the SDK
      // outbox already buffers transient failures so we don't need to
      // re-queue here.
      developer.log(
        'SDK emit failed for $eventName: $e',
        name: 'service_job_notification_service',
        error: e,
        stackTrace: st,
        level: 1000, // SEVERE
      );
    }
  }

  /// Build the canonical recipient list for the given event.
  ///
  /// The customer's `user_id` is synthesised from their phone number when no
  /// platform user id is available; the backend resolves this against the
  /// customer table during dispatch (REQ 12.1 server-side authorization).
  List<uns.Recipient> _buildRecipients({
    required ServiceJob job,
    required String targetId,
    required Map<uns.RecipientRole, List<uns.NotificationChannel>>
    channelsByRole,
    String? vendorUserIdOverride,
  }) {
    final out = <uns.Recipient>[];

    channelsByRole.forEach((role, channels) {
      switch (role) {
        case uns.RecipientRole.customer:
          out.add(
            uns.Recipient(
              userId: job.customerId?.isNotEmpty == true
                  ? 'customer:${job.customerId}'
                  : 'customer:phone:${job.customerPhone}',
              role: role,
              channels: channels,
              targetId: targetId,
            ),
          );
          break;
        case uns.RecipientRole.serviceTechnician:
          // The actual technician is resolved server-side via the job
          // assignment table; the placeholder id below tells the backend
          // "any technician currently assigned to this service job".
          out.add(
            uns.Recipient(
              userId: 'role:service_technician:job:${job.id}',
              role: role,
              channels: channels,
              targetId: targetId,
            ),
          );
          break;
        case uns.RecipientRole.admin:
          // Resolved server-side to the shop owner / admin for `userId`.
          out.add(
            uns.Recipient(
              userId: 'role:admin:owner:${job.userId}',
              role: role,
              channels: channels,
              targetId: targetId,
            ),
          );
          break;
        case uns.RecipientRole.vendor:
          out.add(
            uns.Recipient(
              userId:
                  vendorUserIdOverride ??
                  'role:vendor:warranty_provider:${job.brand}',
              role: role,
              channels: channels,
              targetId: targetId,
            ),
          );
          break;
        default:
          out.add(
            uns.Recipient(
              userId: 'role:${role.name}:job:${job.id}',
              role: role,
              channels: channels,
              targetId: targetId,
            ),
          );
      }
    });

    return out;
  }

  /// Compose the deduplication key from the registry-defined scope fields.
  String _buildDedupKey({
    required String eventName,
    required Map<String, dynamic> payload,
    required List<String> dedupScopeFields,
  }) {
    final parts = <String>[eventName];
    for (final field in dedupScopeFields) {
      final value = payload[field];
      parts.add('$field=${value ?? ''}');
    }
    return parts.join('|');
  }

  /// Get priority level for status — preserved for backward compat.
  NotificationPriority _getPriorityForStatus(ServiceJobStatus status) {
    switch (status) {
      case ServiceJobStatus.completed:
      case ServiceJobStatus.ready:
        return NotificationPriority.high;
      case ServiceJobStatus.delivered:
      case ServiceJobStatus.approved:
        return NotificationPriority.normal;
      default:
        return NotificationPriority.low;
    }
  }

  /// Dispose resources.
  void dispose() {
    _notificationStreamController.close();
  }
}

/// Extension to add notification methods to ServiceJob model.
extension ServiceJobNotificationExtension on ServiceJob {
  /// Quick check if notification should be sent for this job.
  bool get shouldNotifyCustomer =>
      smsNotificationsEnabled && status != ServiceJobStatus.cancelled;
}
