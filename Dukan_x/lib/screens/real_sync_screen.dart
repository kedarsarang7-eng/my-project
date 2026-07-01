import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/engine/sync_engine.dart';
import '../../core/sync/models/sync_types.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../features/sync/presentation/controllers/sync_controller.dart';

class RealSyncScreen extends ConsumerStatefulWidget {
  const RealSyncScreen({super.key});

  @override
  ConsumerState<RealSyncScreen> createState() => _RealSyncScreenState();
}

class _RealSyncScreenState extends ConsumerState<RealSyncScreen> {
  final ScrollController _logScrollController = ScrollController();
  final List<SyncResult> _liveLogs = [];

  @override
  void initState() {
    super.initState();
    // Listen to live sync events for the log
    SyncEngine.instance.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _liveLogs.insert(0, event);
          if (_liveLogs.length > 100) _liveLogs.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: FuturisticColors.error,
          ),
        );
        ref.read(syncControllerProvider.notifier).clearError();
      }

      if (next.message != null && next.message != previous?.message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text(
          'Sync Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: FuturisticColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(syncControllerProvider.notifier).triggerManualSync();
            },
            tooltip: 'Force Sync',
          ),
        ],
      ),
      body: StreamBuilder<SyncStats>(
        stream: SyncEngine.instance.statsStream,
        builder: (context, snapshot) {
          final stats = snapshot.data;

          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final isMobile = context.isMobile;

          final leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Overall Status Card
              _buildStatusHeader(stats),

              const SizedBox(height: 24),

              // 2. Statistics Grid
              const Text(
                'Sync Statistics',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsGrid(stats),
            ],
          );

          final rightColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3. Failed Items List (Async)
              if (stats.failedCount > 0) ...[
                const Text(
                  'Failed Items',
                  style: TextStyle(
                    color: FuturisticColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFailedItemsList(),
                const SizedBox(height: 24),
              ],

              // 4. Live Activity Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Activity Log',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (stats.inProgressCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Syncing...",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActivityLog(),
            ],
          );

          return ResponsiveContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 24),
                        rightColumn,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: leftColumn,
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 6,
                          child: rightColumn,
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(SyncStats stats) {
    bool isSyncing = stats.inProgressCount > 0;
    bool hasErrors = stats.failedCount > 0 || stats.deadLetterCount > 0;

    Color statusColor = FuturisticColors.success;
    IconData statusIcon = Icons.cloud_done;
    String statusTitle = "All Data Synced";
    String statusDesc = "Your local data is safely backed up to the cloud.";

    if (hasErrors) {
      statusColor = FuturisticColors.error;
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = "Sync Attention Needed";
      statusDesc =
          "${stats.failedCount} items failed to sync. Check logs below.";
    } else if (isSyncing) {
      statusColor = Colors.blue;
      statusIcon = Icons.cloud_upload;
      statusTitle = "Syncing in Progress...";
      statusDesc = "Uploading ${stats.pendingCount} pending items.";
    } else if (stats.pendingCount > 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.cloud_queue;
      statusTitle = "Pending Changes";
      statusDesc = "${stats.pendingCount} items waiting to sync.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 16),
          Text(
            statusTitle,
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          if (hasErrors)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(syncControllerProvider.notifier).triggerManualSync();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Failed Items'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(SyncStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          "Pending",
          "${stats.pendingCount}",
          Icons.hourglass_empty,
          Colors.orange,
        ),
        _buildStatCard(
          "Synced Today",
          "${stats.syncedCount}",
          Icons.check_circle_outline,
          FuturisticColors.success,
        ),
        _buildStatCard(
          "In Progress",
          "${stats.inProgressCount}",
          Icons.sync,
          Colors.blue,
        ),
        _buildStatCard(
          "Failed / Dead",
          "${stats.failedCount + stats.deadLetterCount}",
          Icons.error_outline,
          FuturisticColors.error,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedItemsList() {
    return FutureBuilder<List<dynamic>>(
      future: SyncEngine.instance.getFailedItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final failedItems = snapshot.data!;

        if (failedItems.isEmpty) {
          return const Text(
            'No active failed items found',
            style: TextStyle(color: Colors.grey),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: failedItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = failedItems[index];
            return Container(
              decoration: BoxDecoration(
                color: FuturisticColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FuturisticColors.error.withOpacity(0.3),
                ),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.error_outline,
                  color: FuturisticColors.error,
                ),
                title: Text(
                  '${item.targetCollection}/${item.documentId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                subtitle: Text(
                  item.lastError ?? 'Unknown Error',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                  onPressed: () {
                    ref
                        .read(syncControllerProvider.notifier)
                        .triggerManualSync();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityLog() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Terminal-like background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _liveLogs.isEmpty
          ? Center(
              child: Text(
                "Waiting for sync activity...",
                style: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _liveLogs.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final log = _liveLogs[index];
                final time =
                    "${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}";

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.isSuccess
                                  ? "Synced ${log.operationId}"
                                  : "Failed ${log.operationId}",
                              style: TextStyle(
                                color: log.isSuccess
                                    ? FuturisticColors.success
                                    : FuturisticColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (log.failure != null)
                              Text(
                                log.failure!.message,
                                style: TextStyle(
                                  color: FuturisticColors.error.withOpacity(
                                    0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (log.isSuccess)
                        Icon(
                          Icons.check,
                          size: 14,
                          color: FuturisticColors.success.withOpacity(0.5),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
