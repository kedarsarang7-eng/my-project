// ============================================================================
// ANNOUNCEMENTS SCREEN — school_teacher_app
// ----------------------------------------------------------------------------
// Migrated to the Unified Notification System (UNS) under task 14.6.
//
//   * The send-announcement form (compose bottom sheet) is preserved so
//     teachers can still publish a `users.school_announcement.published`
//     event via the existing repository (T-SCH-20 producer is migrated
//     server-side in task 14.7).
//   * The list view is replaced with the canonical `NotificationDrawer`
//     so teachers see the announcements they receive paginated by
//     `created_at` DESC, with `markAsRead` wired to the canonical
//     Notification_Service.
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
        label: const Text('Send', style: TextStyle(color: Colors.white)),
      ),
      body: sdkAsync.when(
        data: (sdk) => NotificationDrawer(
          client: uiClient,
          sdk: sdk,
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
    String audience = 'all_students';
    String? batchId;
    final batches = ref.read(batchesProvider).value ?? [];

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
                'Send Announcement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Send To'),
                items: const [
                  DropdownMenuItem(
                    value: 'all_students',
                    child: Text('All Students'),
                  ),
                  DropdownMenuItem(
                    value: 'all_parents',
                    child: Text('All Parents'),
                  ),
                  DropdownMenuItem(
                    value: 'batch',
                    child: Text('Specific Batch'),
                  ),
                ],
                onChanged: (v) => setS(() => audience = v!),
              ),
              if (audience == 'batch') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: batchId,
                  hint: const Text('Select Batch'),
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: batches
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: (b as Map)['id'],
                          child: Text(b['name'] ?? b['id']),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (subjectCtrl.text.isEmpty || bodyCtrl.text.isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(teacherRepoProvider)
                                .sendAnnouncement({
                              'subject': subjectCtrl.text,
                              'body': bodyCtrl.text,
                              'audience': audience,
                              if (audience == 'batch' && batchId != null)
                                'batchId': batchId,
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Announcement sent!'),
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
                  icon: const Icon(Icons.send),
                  label: const Text('Send Announcement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
