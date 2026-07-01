import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/sync/sync_status_manager.dart';
import '../../core/theme/futuristic_colors.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatusState>(
      stream: SyncStatusManager.instance.statusStream,
      initialData: SyncStatusState.synced, // Ideally load current
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final manager = SyncStatusManager.instance;

        Color color;
        IconData icon;
        String text;

        switch (state) {
          case SyncStatusState.synced:
            color = FuturisticColors.success;
            icon = Icons.cloud_done;
            text = "Data Safe";
            break;
          case SyncStatusState.syncing:
            color = Colors.orange;
            icon = Icons.cloud_upload;
            text = "Syncing... (${manager.pendingWritesCount})";
            break;
          case SyncStatusState.pending:
            color = FuturisticColors.error;
            icon = Icons.cloud_off;
            text = "Pending: ${manager.pendingWritesCount}";
            break;
          case SyncStatusState.failed:
            color = FuturisticColors.error;
            icon = Icons.error_outline;
            text = "Sync Error!";
            break;
        }

        return GestureDetector(
          onTap: () {
            context.push('/sync-status');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
