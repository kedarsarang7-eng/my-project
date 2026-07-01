import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/services/bulk_import_service.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Data Import / Export — import products from CSV (persists via the products
/// repository) and export reports (Sales Register, Customer Ledger, GST Summary)
/// to a shareable file. Reuses BulkImportService and ReportExportService.
class DataImportExportScreen extends ConsumerStatefulWidget {
  const DataImportExportScreen({super.key});

  @override
  ConsumerState<DataImportExportScreen> createState() =>
      _DataImportExportScreenState();
}

class _DataImportExportScreenState
    extends ConsumerState<DataImportExportScreen> {
  bool _busy = false;

  String get _userId => sl<SessionManager>().userId ?? '';

  Future<void> _importProducts() async {
    if (_userId.isEmpty) {
      _toast('Please sign in first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final service = BulkImportService(sl<ProductsRepository>());
      final message = await service.pickAndImportFile(_userId);
      if (mounted) _toast(message);
    } catch (e) {
      if (mounted) _toast('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(
    String label,
    Future<ExportResult> Function(ReportExportService svc) run,
  ) async {
    if (_userId.isEmpty) {
      _toast('Please sign in first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ReportExportService(database: sl<AppDatabase>());
      final result = await run(svc);
      if (!mounted) return;
      if (result.success && result.filePath != null) {
        await Share.shareXFiles([
          XFile(result.filePath!),
        ], subject: '$label export');
        _toast('$label exported (${result.recordCount} records)');
      } else {
        _toast('$label export failed: ${result.error}', error: true);
      }
    } catch (e) {
      if (mounted) _toast('$label export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
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
            title: 'Data Import / Export',
            subtitle: 'Bring data in from CSV or export reports to share',
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
                    'Sign in to access data import and export features.',
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

    final now = DateTime.now();
    final fromDate = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DesktopContentContainer(
          title: 'Data Import / Export',
          subtitle: 'Bring data in from CSV or export reports to share',
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
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                _sectionHeader('Import', isDark),
                _tile(
                  icon: Icons.upload_file_outlined,
                  title: 'Import Products from CSV',
                  subtitle:
                      'Columns: Name, SKU, Category, SellingPrice, '
                      'CostPrice, Stock',
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                  onTap: _busy ? null : _importProducts,
                ),
                const SizedBox(height: 16),
                _sectionHeader('Export (current month)', isDark),
                _tile(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Sales Register',
                  subtitle: 'Export this month\'s sales',
                  color: const Color(0xFF22C55E),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () => _export(
                          'Sales Register',
                          (svc) => svc.exportSalesRegister(
                            userId: _userId,
                            fromDate: fromDate,
                            toDate: now,
                          ),
                        ),
                ),
                _tile(
                  icon: Icons.receipt_long_outlined,
                  title: 'GST Summary',
                  subtitle: 'GSTR-3B style summary',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () => _export(
                          'GST Summary',
                          (svc) => svc.exportGstSummary(
                            userId: _userId,
                            fromDate: fromDate,
                            toDate: now,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : FuturisticColors.textPrimary,
      ),
    ),
  );

  Widget _tile({
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
