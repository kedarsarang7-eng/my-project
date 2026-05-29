// ============================================================================
// NotificationBell — shared Flutter widget for the Unified Notification System.
// ----------------------------------------------------------------------------
// Renders a Material `notifications` icon with the signed-in user's current
// unread count as a badge. Pinned by `phase3-architecture.md` 13.3.
//
// Validates: REQ 11.1, 11.6, 11.6a.
//
// Behaviour summary:
//   * The badge shows the integer returned by `client.unreadCount()`.
//   * The widget refreshes the count on three triggers:
//       (a) initial mount,
//       (b) every `pollInterval` (default 30 s) as a safety net,
//       (c) immediately when the SDK delivers any `onNotification` event.
//   * Stale indicator: every server-side change emitted by the SDK starts a
//     1-second watchdog. If a refresh covers the change in <= 1 s, no
//     indicator. If 1 s elapses with at least one outstanding change still
//     uncovered, the bell shows a small red dot until the next successful
//     refresh runs and covers every pending change.
//
// The widget assumes one `NotificationsSdk` and one `NotificationsUiClient`
// per session, both injected. It does NOT own their lifecycle.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notifications_sdk/notifications_sdk.dart';

import 'notifications_ui_client.dart';

/// Public callback signature so host apps can wire the bell to any drawer
/// (navigation, modal sheet, side panel) they prefer.
typedef NotificationBellOnTap = void Function(BuildContext context);

class NotificationBell extends StatefulWidget {
  /// HTTP client used to read the unread count.
  final NotificationsUiClient client;

  /// SDK used to subscribe to live deliveries so the badge updates as soon
  /// as a server-side change arrives (REQ 11.6 first sentence).
  final NotificationsSdk sdk;

  /// Optional tap handler. When null the bell is non-interactive.
  final NotificationBellOnTap? onTap;

  /// Base poll interval for the safety-net refresh. Defaults to 30 s -- the
  /// live SDK stream covers the 1-second-update target on a connected
  /// client; the poll exists to recover from a missed WebSocket frame.
  final Duration pollInterval;

  /// Threshold beyond which an outstanding server-side change is rendered
  /// as `stale`. Pinned to 1 s by REQ 11.6.
  final Duration staleThreshold;

  /// Maximum count rendered before the badge collapses to `99+`.
  final int maxBadgeCount;

  /// Optional override of the bell icon. Defaults to `Icons.notifications`.
  final IconData icon;

  /// Tooltip when the user hovers over the bell. Defaults to "Notifications".
  final String tooltip;

  const NotificationBell({
    super.key,
    required this.client,
    required this.sdk,
    this.onTap,
    this.pollInterval = const Duration(seconds: 30),
    this.staleThreshold = const Duration(seconds: 1),
    this.maxBadgeCount = 99,
    this.icon = Icons.notifications,
    this.tooltip = 'Notifications',
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  /// Last unread count returned by the backend. Defaults to 0 so the bell
  /// renders immediately without waiting for the first refresh.
  int _count = 0;

  /// True after the very first refresh has completed (success or failure).
  /// Used to suppress the badge until we have a real number.
  bool _initialised = false;

  /// `true` while a refresh round-trip is in flight. Refreshes overlap is
  /// avoided to keep the count monotonic w.r.t. server response order.
  bool _refreshInFlight = false;

  /// Outstanding pending server-side changes, recorded at the instant the
  /// SDK reported them. Each entry is cleared by a successful refresh that
  /// completed strictly after the entry's timestamp.
  final List<DateTime> _pendingChanges = <DateTime>[];

  /// True when at least one pending change has been outstanding longer than
  /// the configured threshold. Cleared on the next successful refresh.
  bool _isStale = false;

  /// Periodic safety-net refresh.
  Timer? _pollTimer;

  /// Watchdog that flips `_isStale` to true once the threshold elapses.
  Timer? _staleWatchdog;

  /// SDK live-delivery stream subscription.
  StreamSubscription<NotificationDelivery>? _onNotificationSub;

  @override
  void initState() {
    super.initState();
    _onNotificationSub = widget.sdk.onNotification().listen(
      _handleServerSideChange,
    );
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _refresh());
    // Kick off the first refresh on the next frame so any provider/scope
    // wiring on the host has a chance to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _staleWatchdog?.cancel();
    _onNotificationSub?.cancel();
    super.dispose();
  }

  /// Called whenever the SDK delivers a notification. The badge cannot
  /// derive the new count from the event alone (the count is per-user,
  /// per-status), so we record the change instant and trigger a refresh.
  void _handleServerSideChange(NotificationDelivery _) {
    final now = DateTime.now();
    setState(() {
      _pendingChanges.add(now);
    });
    _scheduleStaleWatchdog();
    unawaited(_refresh());
  }

  /// Arm or re-arm the watchdog so it fires `staleThreshold` after the
  /// OLDEST pending change. If no pending changes are left, cancel it.
  void _scheduleStaleWatchdog() {
    _staleWatchdog?.cancel();
    if (_pendingChanges.isEmpty) {
      if (_isStale) {
        setState(() {
          _isStale = false;
        });
      }
      return;
    }
    final oldest = _pendingChanges.first;
    final elapsed = DateTime.now().difference(oldest);
    final remaining = widget.staleThreshold - elapsed;
    if (remaining.isNegative || remaining == Duration.zero) {
      // Already past the threshold.
      if (!_isStale) {
        setState(() {
          _isStale = true;
        });
      }
      return;
    }
    _staleWatchdog = Timer(remaining, () {
      if (!mounted) return;
      // Re-check: a refresh might have cleared the queue while we waited.
      if (_pendingChanges.isNotEmpty) {
        setState(() {
          _isStale = true;
        });
      }
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    if (_refreshInFlight) return;
    _refreshInFlight = true;

    // Snapshot the pending-change list at request start. Any change recorded
    // STRICTLY BEFORE the refresh started is "covered" by a successful
    // refresh that completes after it; changes recorded after request start
    // are NOT covered (the server response was already produced).
    final requestStart = DateTime.now();

    try {
      final next = await widget.client.unreadCount();
      if (!mounted) return;
      setState(() {
        _count = next;
        _initialised = true;
        _pendingChanges.removeWhere((t) => t.isBefore(requestStart));
        if (_pendingChanges.isEmpty) {
          _isStale = false;
        }
      });
      _scheduleStaleWatchdog();
    } catch (_) {
      // Refresh failures don't clear pending changes -- the watchdog will
      // mark the bell stale, signalling that something is wrong.
      if (!mounted) return;
      setState(() {
        _initialised = true;
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  String _badgeLabel() {
    if (_count <= 0) return '';
    if (_count > widget.maxBadgeCount) return '${widget.maxBadgeCount}+';
    return '$_count';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBadge = _initialised && _count > 0;
    final label = _badgeLabel();

    final bellIcon = Icon(widget.icon, semanticLabel: widget.tooltip);

    final stack = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        bellIcon,
        if (showBadge)
          Positioned(
            top: -4,
            right: -6,
            child: _Badge(
              label: label,
              backgroundColor: theme.colorScheme.error,
              textColor: theme.colorScheme.onError,
            ),
          ),
        if (_isStale)
          Positioned(
            bottom: -2,
            right: -2,
            child: _StaleDot(color: theme.colorScheme.error),
          ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: stack,
    );

    final tooltip = Tooltip(
      message: _isStale ? '${widget.tooltip} (updating...)' : widget.tooltip,
      child: padded,
    );

    if (widget.onTap == null) return tooltip;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => widget.onTap!(context),
      child: tooltip,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StaleDot extends StatelessWidget {
  final Color color;

  const _StaleDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'stale',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1,
          ),
        ),
      ),
    );
  }
}
