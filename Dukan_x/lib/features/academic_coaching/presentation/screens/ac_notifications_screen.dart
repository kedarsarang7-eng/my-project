// ============================================================================
// ACADEMIC COACHING — NOTIFICATIONS CENTER
// ----------------------------------------------------------------------------
// Migrated to the Unified Notification System (UNS) under task 14.6.
//
//   * The template-sending UI (Fee Reminders / Attendance Alerts / Exam
//     Notices cards on the LEFT) is preserved — admins still trigger
//     bulk SMS / WhatsApp / Email runs through `AcRepository`. Each of
//     those repository calls is a producer that the server-side handler
//     migration (task 14.7 — `school-notifications.ts`) will republish
//     through the canonical Event_Bus.
//   * The previous in-app announcements/inbox panel on the RIGHT
//     (`_buildTemplatesList`) is replaced with the canonical
//     `NotificationDrawer` from `packages/notifications-ui/`. The
//     drawer paginates `created_at` DESC, supports a category filter,
//     and calls `markAsRead` on the canonical Notification_Service when
//     an item is opened.
//
// Validates: REQ 10.6, 10.7, 10.8, 10.9, 11.2, 11.4.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/notifications/uns_providers.dart';
import '../../data/repositories/ac_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcNotificationsScreen extends ConsumerStatefulWidget {
  const AcNotificationsScreen({super.key});

  @override
  ConsumerState<AcNotificationsScreen> createState() =>
      _AcNotificationsScreenState();
}

class _AcNotificationsScreenState extends ConsumerState<AcNotificationsScreen> {
  late final AcRepository _repository;
  bool _isSending = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _repository = sl<AcRepository>();
  }

  Future<void> _sendFeeReminders() async {
    setState(() => _isSending = true);
    try {
      final result = await _repository.sendFeeReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Sent ${result['totalReminders'] ?? 0} fee reminders',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 12, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                Center(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Quick Actions'), icon: Icon(Icons.flash_on)),
                      ButtonSegment(value: 1, label: Text('Inbox'), icon: Icon(Icons.inbox)),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: isMobile
                    ? (_selectedTab == 0 ? _buildQuickActions() : _buildInbox())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildQuickActions()),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _buildInbox()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Center',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Send automated SMS, WhatsApp, and Email notifications',
          style: TextStyle(color: const Color(0xFF64748B), fontSize: isMobile ? 12 : 14),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return ListView(
      children: [
        // Fee Reminders Card
        Container(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Fee Reminders',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Automatically send fee reminders to all parents with pending or overdue fees',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendFeeReminders,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_isSending ? 'Sending...' : 'Send Fee Reminders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Attendance Alerts Card
        Container(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Attendance Alerts',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Notify parents when students are absent for 3+ consecutive days',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Configure Alerts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Exam Notifications Card
        Container(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Exam Notices',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Send exam schedules and result notifications automatically',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Manage Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Right-side panel: replaces the bespoke template list with the shared
  /// `NotificationDrawer`. Admins now see the canonical inbox of every
  /// notification routed to them by the UNS, paginated and filterable
  /// instead of a static template registry.
  Widget _buildInbox() {
    final sdkAsync = ref.watch(notificationsSdkProvider);
    final uiClient = ref.watch(notificationsUiClientProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              'Inbox',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            child: sdkAsync.when(
              data: (sdk) => NotificationDrawer(client: uiClient, sdk: sdk),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load notifications: $e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
