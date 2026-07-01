// ============================================================================
// CUSTOMER NOTIFICATIONS SCREEN
// ============================================================================
// Shows the signed-in customer's notification inbox via the shared UNS
// drawer widget at `packages/notifications-ui/`.
//
// Migration: UNS task 14.5 — replaces the legacy custom inbox UI that read
// straight from the local Drift `customer_notifications` cache. The
// shared drawer paginates `created_at` DESC, supports a category filter,
// and calls `markAsRead` on the canonical Notification_Service when an
// item is opened (REQ 11.2, 11.5).
//
// Author: DukanX Engineering
// Version: 2.0.0 — UNS migration
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../../../../core/notifications/uns_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Customer-facing notifications inbox.
///
/// `customerId` is retained from the legacy signature for route-table
/// compatibility but is no longer used to filter the list — the shared
/// drawer reads from the canonical Notification_Service which scopes
/// items to the signed-in user via the JWT.
class CustomerNotificationsScreen extends ConsumerWidget {
  final String customerId;

  const CustomerNotificationsScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sdkAsync = ref.watch(notificationsSdkProvider);
    final uiClient = ref.watch(notificationsUiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: sdkAsync.when(
        data: (sdk) => NotificationDrawer(client: uiClient, sdk: sdk),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
            child: Text(
              'Could not load notifications: $e',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
