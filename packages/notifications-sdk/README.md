# notifications_sdk

Shared Dart/Flutter SDK for the **Unified Notification System (UNS)**.
Consumed by DukanX and every Sub_App (school admin / teacher / student / etc.).

This package implements the four canonical client methods pinned by
`phase3-architecture.md` §13.2 and validated by tasks 11.1 / 11.2 / 11.4 in
`.kiro/specs/unified-notification-system/tasks.md`.

## Capabilities

- **Public API** — `subscribe(eventName, handler)`, `emit(event)`,
  `onNotification(handler)`, `replay(sinceIso)` (REQ 10.5).
- **Client-side schema validation** — every `emit` payload is validated
  against the canonical `event-contract.schema.json` before the SDK puts it
  on the wire (REQ 8.1, REQ 3.6).
- **Offline outbox** — while disconnected the SDK queues emitted events
  locally and flushes them in `created_at` ascending order on the next
  successful connect (REQ 8.8). The default `FileOutboxStorage` persists to
  JSON Lines under the application documents directory and survives a
  process restart.
- **JWT-bearer auth** — every HTTP and WebSocket call attaches
  `Authorization: Bearer <jwt>`, identical to the existing DukanX/Sub_App
  APIs (REQ 19.1). Apps plug in any token source through `JwtTokenProvider`.
- **Transport** — `http` for `emit` and `replay`, `web_socket_channel` for
  the in-app delivery stream that backs `onNotification`.

## Install (workspace package)

Add to the consumer app's `pubspec.yaml`:

```yaml
dependencies:
  notifications_sdk:
    path: ../packages/notifications-sdk
```

## Quick start

```dart
import 'package:notifications_sdk/notifications_sdk.dart';
import 'package:path_provider/path_provider.dart';

Future<NotificationsSdk> bootSdk(String jwt) async {
  // Load the schema bundled with this package. In a Flutter app prefer
  // `rootBundle.loadString('packages/notifications_sdk/event-contract.schema.json')`.
  final schemaText = await File(
    'packages/notifications-sdk/event-contract.schema.json',
  ).readAsString();
  final validator = SchemaValidator.fromString(schemaText);

  final docs = await getApplicationDocumentsDirectory();
  final outbox = FileOutboxStorage(FileOutboxStorage.defaultPath(docs.path));

  final sdk = NotificationsSdk(
    apiBaseUrl: Uri.parse('https://api.example.com/v1/'),
    tokenProvider: () async => jwt,
    validator: validator,
    outbox: outbox,
  );

  await sdk.connect();
  return sdk;
}
```

### Subscribe to a named event

```dart
final unsubscribe = sdk.subscribe('billing.invoice.created', (n) {
  // n is a NotificationDelivery; n.payload holds the event-specific fields.
});
```

### Emit an event

```dart
final event = sdk.buildEvent(
  eventName: 'billing.invoice.created',
  category: EventCategory.billing,
  priority: EventPriority.normal,
  actorId: currentUserId,
  targetId: invoiceId,
  recipients: [
    Recipient(userId: customerId, role: RecipientRole.customer),
  ],
  payload: {'invoice_id': invoiceId, 'amount': 1200},
  channels: [NotificationChannel.inApp, NotificationChannel.push],
  sourceModule: 'Dukan_x/lib/features/billing/...',
  sourceApp: SourceApp.dukanxDesktop,
  dedupKey: 'billing.invoice.created:$currentUserId:$invoiceId',
  dedupScopeFields: ['invoice_id'],
);
await sdk.emit(event);
```

If the device is offline the event is appended to the outbox and replayed
in `created_at` ASC order on the next `connect()` (REQ 8.8).

### Replay missed events after reconnect

```dart
final since = lastSeenAt.toUtc().toIso8601String();
final replayed = await sdk.replay(since, appName: 'school_student_app');
```

### Listen to every delivered notification

```dart
sdk.onNotification().listen((n) {
  // Bell counter / drawer / toast can react here.
});
```

## Architecture references

- Public API contract — `phase3-architecture.md` §13.2
- Event_Contract schema — `packages/notifications-sdk/event-contract.schema.json`
- Offline outbox semantics — `requirements.md` REQ 8.8, REQ 9.7
- JWT auth — `requirements.md` REQ 19.1, `phase3-architecture.md` §14.1

## Validates

REQ 8.1, 8.8, 10.5, 19.1.
