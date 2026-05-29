# notifications_ui

Shared Flutter widgets for the **Unified Notification System (UNS)**.
Consumed by DukanX and every Sub_App (school admin / teacher / student / etc.).

This package implements the four canonical UI surfaces pinned by
`phase3-architecture.md` §13.3 and validated by REQ 11 in `requirements.md`:

- **`NotificationBell`** — unread-count badge with a `stale` indicator
  (REQ 11.1, 11.6, 11.6a).
- **`NotificationDrawer`** — `created_at` DESC list with cursor pagination
  and category filter; calls `markAsRead` on item open (REQ 11.2, 11.5).
- **`NotificationToastHost`** — Material `SnackBar` for newly arrived
  `critical` and `high` priority notifications (REQ 11.3).
- **`NotificationPreferencesPage`** — per-category channels, per-event
  channels, Quiet_Hours, and `mute_targets` (REQ 11.4).

The widgets pair with the canonical SDK at `packages/notifications-sdk/`
for the live-delivery stream and an internal `NotificationsUiClient` for
the read/write HTTP endpoints (`unread-count`, `list`, `markAsRead`,
`getUserPreferences`, `setUserPreferences`) — kept off the SDK envelope on
purpose so the four-method SDK contract stays pinned.

## Install (workspace package)

Add to the consumer app's `pubspec.yaml`:

```yaml
dependencies:
  notifications_ui:
    path: ../packages/notifications-ui
  notifications_sdk:
    path: ../packages/notifications-sdk
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:notifications_sdk/notifications_sdk.dart';
import 'package:notifications_ui/notifications_ui.dart';

class App extends StatefulWidget {
  const App({super.key, required this.sdk, required this.uiClient});
  final NotificationsSdk sdk;
  final NotificationsUiClient uiClient;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: NotificationToastHost(
        sdk: widget.sdk,
        scaffoldMessengerKey: messengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
            actions: <Widget>[
              NotificationBell(
                client: widget.uiClient,
                sdk: widget.sdk,
                onTap: (ctx) {
                  showModalBottomSheet(
                    context: ctx,
                    builder: (_) => SizedBox(
                      height: 480,
                      child: NotificationDrawer(
                        client: widget.uiClient,
                        sdk: widget.sdk,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationPreferencesPage(client: widget.uiClient),
                ),
              ),
              child: const Text('Notification settings'),
            ),
          ),
        ),
      ),
    );
  }
}
```

### Wiring the UI client

```dart
final uiClient = NotificationsUiClient(
  apiBaseUrl: Uri.parse('https://api.example.com/v1/'),
  tokenProvider: () async => currentJwt,
);
```

## Key behaviours

### Bell stale indicator

The bell tracks every server-side change reported by the SDK's
`onNotification` stream. If a refresh covers a pending change in ≤ 1 s, no
indicator. If 1 s elapses with at least one outstanding change still
uncovered, a small dot appears beside the bell until the next successful
refresh runs and covers every pending change. Pinned to 1 s by REQ 11.6 /
11.6a; configurable via `staleThreshold`.

### Drawer pagination

The drawer calls `client.listNotifications(cursor, category, limit)` and
appends items in `created_at` DESC order. The next page is pre-fetched
when the user is within 240 px of the bottom; `nextCursor == null` ends
the list. Selecting a different category chip resets the cursor and
reloads the first page.

### Toast filter

`NotificationToastHost` listens to `sdk.onNotification()` and shows a
SnackBar only when the delivery's `priority` is `critical` or `high`. Lower
priorities are intentionally suppressed — the bell + drawer carry them.

### Preferences

`NotificationPreferencesPage` loads the current preferences via
`client.getUserPreferences()`, mutates them locally, and persists via
`client.setUserPreferences(prefs)` on save. The endpoint is idempotent
(REQ 4.9 / REQ 7.7), so retries produce the same stored state.

## Validates

REQ 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.6a.

## Architecture references

- Widget surface — `phase3-architecture.md` §13.3
- HTTP endpoints — `phase3-architecture.md` §14.3
- Acceptance criteria — `requirements.md` Requirement 11
