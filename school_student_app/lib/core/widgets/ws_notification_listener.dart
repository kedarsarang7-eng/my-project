import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../websocket/school_ws_service.dart';

/// Wrap this around any screen tree to show real-time push banners.
/// Usage: WsNotificationListener(child: YourWidget())
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

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        content: Row(children: [
          Icon(_iconForType(event.type), color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              if (body.isNotEmpty) Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )),
        ]),
      ),
    );
  }

  String _titleForType(String type) => switch (type) {
    'fee_paid'          => 'Fee Payment',
    'announcement'      => 'Announcement',
    'homework_assigned' => 'New Homework',
    'exam_scheduled'    => 'Exam Scheduled',
    'leave_update'      => 'Leave Update',
    _                   => 'Notification',
  };

  Color _colorForCategory(String cat) => switch (cat) {
    'fee'         => const Color(0xFF16A34A),
    'exam'        => const Color(0xFF7C3AED),
    'homework'    => const Color(0xFF0891B2),
    'leave'       => const Color(0xFFD97706),
    'emergency'   => const Color(0xFFDC2626),
    _             => const Color(0xFF4F46E5),
  };

  IconData _iconForType(String type) => switch (type) {
    'fee_paid'          => Icons.check_circle_rounded,
    'announcement'      => Icons.campaign_rounded,
    'homework_assigned' => Icons.assignment_rounded,
    'exam_scheduled'    => Icons.quiz_rounded,
    'leave_update'      => Icons.event_note_rounded,
    _                   => Icons.notifications_rounded,
  };
}
