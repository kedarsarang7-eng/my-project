import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ErrorLogsScreen extends ConsumerStatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  ConsumerState<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends ConsumerState<ErrorLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _errorLogs = [
    {
      'time': DateTime.now().subtract(const Duration(minutes: 5)),
      'level': 'ERROR',
      'source': 'SyncManager',
      'message': 'Network timeout while syncing batch #84920',
    },
    {
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'level': 'WARNING',
      'source': 'InventoryService',
      'message': 'Low memory warning detected during large import',
    },
    {
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'level': 'INFO',
      'source': 'System',
      'message': 'Backup completed successfully',
    },
  ];

  final List<Map<String, dynamic>> _syncQueue = [
    {
      'id': 'SYNC-001',
      'action': 'CREATE_BILL',
      'status': 'PENDING',
      'retries': 0,
    },
    {
      'id': 'SYNC-002',
      'action': 'UPDATE_STOCK',
      'status': 'FAILED',
      'retries': 3,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'System Logs & Sync',
      subtitle: 'Monitor errors and sync status',
      actions: [
        DesktopIconButton(
          icon: Icons.upload_file,
          tooltip: 'Export Logs',
          onPressed: () {},
        ),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: () => setState(() {}),
        ),
      ],
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: FuturisticColors.primary,
              unselectedLabelColor: FuturisticColors.textSecondary,
              indicatorColor: FuturisticColors.primary,
              tabs: const [
                Tab(text: 'Error Logs', icon: Icon(Icons.error_outline)),
                Tab(text: 'Sync Queue', icon: Icon(Icons.cloud_queue)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildErrorLogList(), _buildSyncQueueList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _errorLogs.length,
      itemBuilder: (context, index) {
        final log = _errorLogs[index];
        final isError = log['level'] == 'ERROR';
        final isWarning = log['level'] == 'WARNING';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            child: ListTile(
              leading: Icon(
                isError
                    ? Icons.error
                    : (isWarning ? Icons.warning : Icons.info),
                color: isError
                    ? FuturisticColors.error
                    : (isWarning
                          ? FuturisticColors.warning
                          : FuturisticColors.success),
              ),
              title: Text(
                log['message'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${log['source']} • ${_formatTime(log['time'])}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              trailing: isError
                  ? IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {},
                      tooltip: 'Retry Action',
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncQueueList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syncQueue.length,
      itemBuilder: (context, index) {
        final item = _syncQueue[index];
        final isFailed = item['status'] == 'FAILED';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            child: ListTile(
              leading: const Icon(
                Icons.cloud_upload_outlined,
                color: FuturisticColors.accent1,
              ),
              title: Text(
                item['action'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'ID: ${item['id']} • Retries: ${item['retries']}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              trailing: Chip(
                label: Text(item['status']),
                backgroundColor: isFailed
                    ? FuturisticColors.error.withOpacity(0.2)
                    : Colors.white10,
                labelStyle: TextStyle(
                  color: isFailed ? FuturisticColors.error : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
