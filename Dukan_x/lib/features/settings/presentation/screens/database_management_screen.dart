import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_optimizer.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Database Management — surfaces real SQLite maintenance: size/status,
/// integrity check, ANALYZE (statistics) and VACUUM (compaction). All actions
/// delegate to [DatabaseOptimizer]; nothing here fakes a result.
class DatabaseManagementScreen extends ConsumerStatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  ConsumerState<DatabaseManagementScreen> createState() =>
      _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState
    extends ConsumerState<DatabaseManagementScreen> {
  AppDatabase get _db => sl<AppDatabase>();

  String get _userId => sl<SessionManager>().userId ?? '';

  Map<String, dynamic>? _status;
  bool _busy = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await DatabaseOptimizer.getOptimizationStatus(_db);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _run(String label, Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final ok = await action();
    await _refreshStatus();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = '$label: ${ok ? 'success' : 'failed'}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ${ok ? 'completed' : 'failed'}'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _runIntegrityCheck() async {
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final result = await DatabaseOptimizer.integrityCheck(_db);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = 'Integrity: ${result.ok ? 'OK' : 'ISSUES'}';
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(result.ok ? 'Database Healthy' : 'Integrity Issues Found'),
        content: Text(result.details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    // Null guard: show fallback UI when user is not signed in
    if (_userId.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: DesktopContentContainer(
            title: 'Database Management',
            subtitle: 'Inspect and maintain the local database',
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please sign in',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to access database management features.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final size = _status?['dbSizeBytes'] as int?;
    final journal = _status?['journalMode']?.toString() ?? '—';
    final pages = _status?['pageCount']?.toString() ?? '—';
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DesktopContentContainer(
          title: 'Database Management',
          subtitle: 'Inspect and maintain the local database',
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('Database Status', isDark),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow(
                        'Size',
                        size != null ? _formatBytes(size) : '—',
                        textPrimary,
                      ),
                      _statRow('Journal mode', journal, textPrimary),
                      _statRow('Page count', pages, textPrimary),
                      if (_lastResult != null) ...[
                        Divider(height: 24, color: cardBorder),
                        Text(
                          'Last action — $_lastResult',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                _section('Maintenance', isDark),
                const SizedBox(height: 12),
                _actionTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Run Integrity Check',
                  subtitle: 'Detect corruption (read-only)',
                  color: const Color(0xFF22C55E),
                  isDark: isDark,
                  onTap: _busy ? null : _runIntegrityCheck,
                ),
                _actionTile(
                  icon: Icons.insights_outlined,
                  title: 'Optimize Statistics (ANALYZE)',
                  subtitle: 'Improve query planning',
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () => _run(
                          'ANALYZE',
                          () => DatabaseOptimizer.analyzeDatabase(_db),
                        ),
                ),
                _actionTile(
                  icon: Icons.compress_outlined,
                  title: 'Compact Database (VACUUM)',
                  subtitle: 'Reclaim unused space (may take time)',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () => _run(
                          'VACUUM',
                          () => DatabaseOptimizer.vacuumDatabase(_db),
                        ),
                ),
                _actionTile(
                  icon: Icons.speed_outlined,
                  title: 'Enable WAL Mode',
                  subtitle: 'Faster concurrent writes',
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () => _run(
                          'WAL',
                          () => DatabaseOptimizer.enableWalMode(_db),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : FuturisticColors.textPrimary,
      ),
    ),
  );

  Widget _statRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    ),
  );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
