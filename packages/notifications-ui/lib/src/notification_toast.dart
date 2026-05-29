// ============================================================================
// NotificationToastHost — shared Flutter widget for the Unified Notification System.
// ----------------------------------------------------------------------------
// Listens to `sdk.onNotification()` and surfaces newly arrived `critical`
// and `high` priority notifications as a Material `SnackBar` (or, if the
// host opts in, a custom overlay).
//
// Validates: REQ 11.3.
//
// Usage: wrap once near the app root, just below the `MaterialApp`:
//
//     MaterialApp(
//       scaffoldMessengerKey: messengerKey,
//       home: NotificationToastHost(
//         sdk: sdk,
//         scaffoldMessengerKey: messengerKey,
//         child: HomeScreen(),
//       ),
//     )
//
// The host is non-rendering; it returns `child` unchanged and only schedules
// SnackBars on the supplied `ScaffoldMessenger`.
//
// Priority filter is fixed to `critical` and `high` per REQ 11.3. Lower
// priorities are intentionally suppressed -- the bell + drawer carry them.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notifications_sdk/notifications_sdk.dart';

const Set<String> _kToastPriorities = <String>{'critical', 'high'};

/// Optional builder so host apps can replace the default SnackBar with a
/// custom widget (overlay banner, system tray alert, etc.). When supplied,
/// the default SnackBar is NOT shown.
typedef NotificationToastBuilder =
    void Function(BuildContext context, NotificationDelivery delivery);

class NotificationToastHost extends StatefulWidget {
  /// SDK whose live-delivery stream feeds the toast.
  final NotificationsSdk sdk;

  /// Required scaffold messenger key. The host MUST be able to reach a
  /// messenger -- without it there is no SnackBar surface available.
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  /// Custom toast builder. When null, the default Material SnackBar is used.
  final NotificationToastBuilder? builder;

  /// Default duration for the SnackBar. Pinned to 5 s for `high` and 8 s
  /// for `critical` so an alert isn't dismissed before it's read.
  final Duration highDuration;
  final Duration criticalDuration;

  /// Optional tap-through callback fired when the SnackBar action is
  /// pressed. Lets host apps navigate to the originating screen.
  final void Function(NotificationDelivery delivery)? onAction;

  /// Subtree that the host wraps -- returned unchanged; the host doesn't
  /// add any visual chrome of its own.
  final Widget child;

  const NotificationToastHost({
    super.key,
    required this.sdk,
    required this.scaffoldMessengerKey,
    required this.child,
    this.builder,
    this.highDuration = const Duration(seconds: 5),
    this.criticalDuration = const Duration(seconds: 8),
    this.onAction,
  });

  @override
  State<NotificationToastHost> createState() => _NotificationToastHostState();
}

class _NotificationToastHostState extends State<NotificationToastHost> {
  StreamSubscription<NotificationDelivery>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.sdk.onNotification().listen(_onDelivery);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onDelivery(NotificationDelivery delivery) {
    if (!mounted) return;
    if (!_kToastPriorities.contains(delivery.priority.toLowerCase())) {
      // REQ 11.3 -- only `critical`/`high` surface as toasts.
      return;
    }

    final messenger = widget.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    if (widget.builder != null) {
      // Use the host context: the SDK delivery isn't tied to a particular
      // BuildContext, so we pick the messenger's context to drive the
      // builder. Host overlays / tray icons can pull their own state.
      widget.builder!(messenger.context, delivery);
      return;
    }

    final isCritical = delivery.priority.toLowerCase() == 'critical';
    final duration = isCritical ? widget.criticalDuration : widget.highDuration;

    final title =
        (delivery.payload['title'] as String?) ??
        (delivery.payload['subject'] as String?) ??
        delivery.eventName;
    final body =
        (delivery.payload['body'] as String?) ??
        (delivery.payload['message'] as String?) ??
        '';

    messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.swipe);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isCritical
            ? Theme.of(messenger.context).colorScheme.error
            : null,
        duration: duration,
        content: _ToastContent(
          title: title,
          body: body,
          isCritical: isCritical,
        ),
        action: widget.onAction == null
            ? null
            : SnackBarAction(
                label: 'View',
                textColor: isCritical
                    ? Theme.of(messenger.context).colorScheme.onError
                    : null,
                onPressed: () => widget.onAction!(delivery),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ToastContent extends StatelessWidget {
  final String title;
  final String body;
  final bool isCritical;

  const _ToastContent({
    required this.title,
    required this.body,
    required this.isCritical,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCritical
        ? Theme.of(context).colorScheme.onError
        : Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(isCritical ? Icons.error : Icons.warning_amber, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              if (body.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: color),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
