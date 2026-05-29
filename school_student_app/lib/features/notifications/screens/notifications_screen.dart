// ============================================================================
// NOTIFICATIONS SCREEN — school_student_app
// ----------------------------------------------------------------------------
// Migrated to the Unified Notification System (UNS) under task 14.6.
// Replaces the bespoke per-app inbox UI with the canonical
// `NotificationDrawer` widget from `packages/notifications-ui/`.
//
// Validates: REQ 10.6, 10.7, 10.8, 10.9, 11.2, 11.4.
// Migration ledger row: T-SCH-* (consumer side; producers migrate in 14.7).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../../../core/notifications/uns_providers.dart';
import '../../../core/widgets/widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sdkAsync = ref.watch(notificationsSdkProvider);
    final uiClient = ref.watch(notificationsUiClientProvider);

    return PageScaffold(
      title: 'Notifications',
      body: sdkAsync.when(
        data: (sdk) => NotificationDrawer(client: uiClient, sdk: sdk),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load notifications: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
