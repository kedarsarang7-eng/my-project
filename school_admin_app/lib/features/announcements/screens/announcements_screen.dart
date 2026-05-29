// ============================================================================
// ANNOUNCEMENTS SCREEN — school_admin_app
// ----------------------------------------------------------------------------
// Migrated to the Unified Notification System (UNS) under task 14.6.
//
//   * The publish-announcement form (broadcast bottom sheet) is preserved
//     so admins can still send a `users.school_announcement.published`
//     event via the existing repository (T-SCH-20 producer is migrated
//     server-side in task 14.7).
//   * The list view that previously showed only an empty-state placeholder
//     is replaced with the canonical `NotificationDrawer` so admins see
//     their delivered announcements alongside every other notification
//     they receive — paginated, category-filterable, with `markAsRead`
//     wired to the canonical Notification_Service.
//
// Validates: REQ 10.6, 10.7, 10.8, 10.9, 11.2, 11.4.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../../../core/notifications/uns_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sdkAsync = ref.watch(notificationsSdkProvider);
    final uiClient = ref.watch(notificationsUiClientProvider);

    return PageScaffold(
      title: 'Announcements',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showComposeSheet(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text('Broadcast', style: TextStyle(color: Colors.white)),
      ),
      body: sdkAsync.when(
        data: (sdk) => NotificationDrawer(
          client: uiClient,
          sdk: sdk,
          // Admins primarily care about announcements; they can clear the
          // chip to see everything.
          initialCategory: 'users',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load announcements: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _showComposeSheet(BuildContext context, WidgetRef ref) {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';
    final batches = ref.read(batchesProvider).value ?? [];
    String? batchId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Broadcast Announcement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(
                    value: 'all_students',
                    child: Text('All Students'),
                  ),
                  DropdownMenuItem(
                    value: 'all_parents',
                    child: Text('All Parents'),
                  ),
                  DropdownMenuItem(
                    value: 'all_faculty',
                    child: Text('All Faculty'),
                  ),
                  DropdownMenuItem(
                    value: 'batch',
                    child: Text('Specific Class'),
                  ),
                ],
                onChanged: (v) => setS(() => audience = v!),
              ),
              if (audience == 'batch') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: batchId,
                  hint: const Text('Select Class'),
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: batches
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: (b as Map)['id'],
                          child: Text(b['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setS(() => batchId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: 'Subject *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Message *'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sms_outlined, size: 16),
                      label: const Text('SMS'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (subjectCtrl.text.isEmpty || bodyCtrl.text.isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref.read(adminRepoProvider).sendAnnouncement({
                              'subject': subjectCtrl.text,
                              'body': bodyCtrl.text,
                              'audience': audience,
                              if (audience == 'batch' && batchId != null)
                                'batchId': batchId,
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Announcement broadcast!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
