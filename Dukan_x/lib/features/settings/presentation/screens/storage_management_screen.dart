import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Storage Management — shows real on-disk usage for the app's documents, cache
/// and temp directories, and lets the user clear the cache/temp safely (never
/// the documents dir, which holds the database and backups).
class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  ConsumerState<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState
    extends ConsumerState<StorageManagementScreen> {
  int? _docsBytes;
  int? _cacheBytes;
  int? _tempBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<int> _dirSize(Directory? dir) async {
    if (dir == null || !dir.existsSync()) return 0;
    var total = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          total += await e.length();
        }
      }
    } catch (_) {
      // Permission or transient IO error — return what we counted so far.
    }
    return total;
  }

  Future<void> _measure() async {
    setState(() => _busy = true);
    final docs = await getApplicationDocumentsDirectory();
    final temp = await getTemporaryDirectory();
    Directory? cache;
    try {
      cache = await getApplicationCacheDirectory();
    } catch (_) {
      cache = null;
    }
    final docsSize = await _dirSize(docs);
    final cacheSize = await _dirSize(cache);
    final tempSize = await _dirSize(temp);
    if (!mounted) return;
    setState(() {
      _docsBytes = docsSize;
      _cacheBytes = cacheSize;
      _tempBytes = tempSize;
      _busy = false;
    });
  }

  Future<void> _clearCacheAndTemp() async {
    setState(() => _busy = true);
    var freed = 0;
    for (final getter in <Future<Directory?> Function()>[
      () async {
        try {
          return await getApplicationCacheDirectory();
        } catch (_) {
          return null;
        }
      },
      () async => getTemporaryDirectory(),
    ]) {
      final dir = await getter();
      if (dir == null || !dir.existsSync()) continue;
      try {
        await for (final e in dir.list(followLinks: false)) {
          try {
            if (e is File) {
              freed += await e.length();
              await e.delete();
            } else if (e is Directory) {
              freed += await _dirSize(e);
              await e.delete(recursive: true);
            }
          } catch (_) {
            // Skip files locked by the OS.
          }
        }
      } catch (_) {}
    }
    await _measure();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared ${_formatBytes(freed)} of cache')),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);

    final isMobile = context.isMobile;

    return DesktopContentContainer(
      title: 'Storage Management',
      subtitle: 'View on-device usage and free up space',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 12, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Usage', isDark),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 280),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _usageRow(
                    'App data (database, backups)',
                    _formatBytes(_docsBytes),
                    textPrimary,
                  ),
                  _usageRow('Cache', _formatBytes(_cacheBytes), textPrimary),
                  _usageRow(
                    'Temporary files',
                    _formatBytes(_tempBytes),
                    textPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            isMobile
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _measure,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recalculate'),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _busy ? null : _measure,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recalculate'),
                  ),
            const SizedBox(height: 8),
            isMobile
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _clearCacheAndTemp,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clear Cache & Temp Files'),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _busy ? null : _clearCacheAndTemp,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Clear Cache & Temp Files'),
                  ),
            const SizedBox(height: 8),
            Text(
              'App data (your database and backups) is never deleted here.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
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

  Widget _usageRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    ),
  );
}
