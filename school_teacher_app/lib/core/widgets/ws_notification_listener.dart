import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../websocket/school_ws_service.dart';

class WsNotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  const WsNotificationListener({required this.child, super.key});

  @override
  ConsumerState<WsNotificationListener> createState() => _State();
}

class _State extends ConsumerState<WsNotificationListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schoolWsServiceProvider).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<WsEvent>>(wsNotificationsProvider, (prev, next) {
      if (next.isEmpty) return;
      final latest = next.first;
      if (prev != null && prev.isNotEmpty && prev.first == latest) return;
      _showBanner(context, latest);
    });
    return widget.child;
  }

  void _showBanner(BuildContext ctx, WsEvent event) {
    final title = event.title ?? _titleForType(event.type);
    final body = event.body ?? '';
    final color = _colorForCategory(event.category ?? event.type);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: color,
      content: Row(children: [
        Icon(_iconForType(event.type), color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          if (body.isNotEmpty) Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
      ]),
    ));
  }

  String _titleForType(String type) => switch (type) {
    'leave_approved'    => 'Leave Approved',
    'leave_rejected'    => 'Leave Rejected',
    'attendance_synced' => 'Attendance Synced',
    'announcement'      => 'Announcement',
    _                   => 'Notification',
  };

  Color _colorForCategory(String cat) => switch (cat) {
    'leave'     => const Color(0xFFD97706),
    'emergency' => const Color(0xFFDC2626),
    'system'    => const Color(0xFF0F766E),
    _           => const Color(0xFF0F766E),
  };

  IconData _iconForType(String type) => switch (type) {
    'leave_approved'    => Icons.check_circle_rounded,
    'leave_rejected'    => Icons.cancel_rounded,
    'attendance_synced' => Icons.cloud_done_rounded,
    'announcement'      => Icons.campaign_rounded,
    _                   => Icons.notifications_rounded,
  };
}
