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
      duration: const Duration(seconds: 5),
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
    'new_admission'  => 'New Admission',
    'fee_received'   => 'Fee Received',
    'leave_request'  => 'Leave Request',
    'system_alert'   => 'System Alert',
    'announcement'   => 'Announcement',
    _                => 'Admin Alert',
  };

  Color _colorForCategory(String cat) => switch (cat) {
    'admission' => const Color(0xFF7C3AED),
    'fee'       => const Color(0xFF16A34A),
    'leave'     => const Color(0xFFD97706),
    'emergency' => const Color(0xFFDC2626),
    _           => const Color(0xFF1E40AF),
  };

  IconData _iconForType(String type) => switch (type) {
    'new_admission' => Icons.how_to_reg_rounded,
    'fee_received'  => Icons.payments_rounded,
    'leave_request' => Icons.event_note_rounded,
    'system_alert'  => Icons.warning_rounded,
    _               => Icons.notifications_rounded,
  };
}
