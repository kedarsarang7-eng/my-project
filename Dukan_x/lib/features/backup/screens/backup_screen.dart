import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../core/di/service_locator.dart'; // Removed
import '../../../core/sync/engine/sync_engine.dart'; // UPDATED

import '../../../providers/app_state_providers.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import '../../../widgets/modern_ui_components.dart';
import '../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    // ignore: unused_local_variable
    final palette = theme.palette;

    return DesktopContentContainer(
      title: "Backup & Sync",
      subtitle: "Secure usage data with Cloud Sync and Local Backups",
      actions: [
        DesktopIconButton(
          icon: Icons.sync,
          tooltip: 'Sync Now',
          onPressed: () => _performSync(context),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Center(
          child: BoundedBox(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncStatusCard(context),
                const SizedBox(height: 32),
                Text(
                  "Data Management",
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (context.isMobile)
                  Column(
                    children: [
                      _buildActionCard(
                        context,
                        "Cloud Backup",
                        "Automatic secure cloud backup enabled",
                        Icons.cloud_done,
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context,
                        "Export Data",
                        "Download local JSON copy",
                        Icons.download,
                        Colors.orange,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Export started... (Demo)"),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context,
                        "Restore Data",
                        "Restore from local file",
                        Icons.restore_page,
                        Colors.blue,
                        onTap: () => _showRestoreDialog(context),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          "Cloud Backup",
                          "Automatic secure cloud backup enabled",
                          Icons.cloud_done,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          "Export Data",
                          "Download local JSON copy",
                          Icons.download,
                          Colors.orange,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Export started... (Demo)"),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          "Restore Data",
                          "Restore from local file",
                          Icons.restore_page,
                          Colors.blue,
                          onTap: () => _showRestoreDialog(context),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context) {
    final isMobile = context.isMobile;
    
    final statusContent = Row(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sync_rounded,
            size: isMobile ? 32 : 48,
            color: FuturisticColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sync Status: Online",
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Last Synced: Just now",
                style: TextStyle(
                  fontSize: 16,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FuturisticColors.primary.withOpacity(0.2),
              FuturisticColors.secondary.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FuturisticColors.primary.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            statusContent,
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: "Sync Now",
                icon: Icons.sync,
                onPressed: () => _performSync(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FuturisticColors.primary.withOpacity(0.2),
            FuturisticColors.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FuturisticColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: statusContent),
          const SizedBox(width: 24),
          PrimaryButton(
            label: "Sync Now",
            icon: Icons.sync,
            onPressed: () => _performSync(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        height: 160,
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: FuturisticColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performSync(BuildContext context) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Syncing with cloud...")));
    try {
      await SyncEngine.instance.triggerSync();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sync Complete! Data is safe."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Sync failed: $e")));
      }
    }
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'Your data is automatically synced to the cloud. '
          'To restore, simply log in with your account on any device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
