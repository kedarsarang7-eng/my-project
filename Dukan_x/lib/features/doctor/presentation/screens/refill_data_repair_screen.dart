import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RefillDataRepairScreen extends StatefulWidget {
  const RefillDataRepairScreen({super.key});

  @override
  State<RefillDataRepairScreen> createState() => _RefillDataRepairScreenState();
}

class _RefillDataRepairScreenState extends State<RefillDataRepairScreen> {
  final ApiClient _api = sl<ApiClient>();
  bool _loading = true;
  bool _loadingMore = false;
  bool _updating = false;
  String? _error;
  List<Map<String, dynamic>> _incompleteItems = const [];
  String? _nextCursor;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadIncomplete();
  }

  Future<void> _loadIncomplete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/pharmacy/prescriptions/refills/incomplete?page=1&pageSize=50',
      );
      if (!res.isSuccess || res.data == null) {
        setState(() {
          _error = res.error ?? 'Failed to load incomplete refill rows';
          _loading = false;
        });
        return;
      }
      final data = Map<String, dynamic>.from(res.data!);
      final rows = List<Map<String, dynamic>>.from(data['data'] ?? const []);
      final meta = Map<String, dynamic>.from(data['meta'] ?? const {});
      setState(() {
        _incompleteItems = rows;
        _nextCursor = meta['nextCursor']?.toString();
        _hasMore = meta['hasMore'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreIncomplete() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _api.get(
        '/pharmacy/prescriptions/refills/incomplete?cursor=${Uri.encodeComponent(_nextCursor!)}&pageSize=50',
      );
      if (!res.isSuccess || res.data == null) return;
      final data = Map<String, dynamic>.from(res.data!);
      final rows = List<Map<String, dynamic>>.from(data['data'] ?? const []);
      final meta = Map<String, dynamic>.from(data['meta'] ?? const {});
      setState(() {
        _incompleteItems = [..._incompleteItems, ...rows];
        _nextCursor = meta['nextCursor']?.toString();
        _hasMore = meta['hasMore'] == true;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _backfillTrace(Map<String, dynamic> item) async {
    final productCtrl = TextEditingController(
      text: item['productId']?.toString() ?? '',
    );
    final prescribedCtrl = TextEditingController(
      text: (item['prescribedQty'] ?? item['requestedQty'] ?? 1).toString(),
    );
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backfill Refill Trace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: productCtrl,
              decoration: const InputDecoration(labelText: 'Product ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: prescribedCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prescribed Qty'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Backfill'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final productId = productCtrl.text.trim();
    final prescribedQty = int.tryParse(prescribedCtrl.text.trim()) ?? 0;
    if (productId.isEmpty || prescribedQty <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product ID and prescribed qty required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _updating = true);
    try {
      final res = await _api.post(
        '/pharmacy/prescriptions/refills/backfill',
        body: {
          'refillId': item['id']?.toString() ?? '',
          'productId': productId,
          'prescribedQty': prescribedQty,
        },
      );
      if (!res.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Backfill failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      await _loadIncomplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backfill complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _bulkFixPrescribedQty() async {
    final candidates = _incompleteItems.where((r) {
      final hasProduct =
          r['productId'] != null && (r['productId'] as String).trim().isNotEmpty;
      final missingPrescribed =
          r['prescribedQty'] == null ||
          (r['prescribedQty'] as num?)?.toInt() == 0;
      return hasProduct && missingPrescribed;
    }).toList();

    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No rows eligible for bulk prescribed-qty fix'),
          ),
        );
      }
      return;
    }

    final mode = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bulk Backfill Mode'),
        content: const Text(
          'Choose Preview to validate rows without writing changes, or Apply to perform updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Preview'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (mode == null) return;
    final isPreview = mode;

    setState(() => _updating = true);
    try {
      final payload = candidates
          .map(
            (r) => {
              'refillId': r['id']?.toString() ?? '',
              'productId': r['productId']?.toString() ?? '',
              'prescribedQty': (r['requestedQty'] as num?)?.toInt() ?? 1,
            },
          )
          .toList();
      final res = await _api.post(
        '/pharmacy/prescriptions/refills/backfill/bulk',
        body: {
          'items': payload,
          'preview': isPreview,
        },
      );

      if (!res.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Bulk fix failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!isPreview) {
        await _loadIncomplete();
      }
      final data = res.data == null ? null : Map<String, dynamic>.from(res.data!);
      final successCount = (data?['successCount'] as num?)?.toInt() ?? payload.length;
      final failedCount = (data?['failedCount'] as num?)?.toInt() ?? 0;
      final failedRows = _extractFailedRows(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPreview
                  ? 'Preview complete: $successCount valid, $failedCount failed'
                  : 'Bulk fix done: $successCount updated, $failedCount failed',
            ),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }

      if (failedRows.isNotEmpty && mounted) {
        final export = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Failed Rows'),
            content: Text(
              '$failedCount rows failed. Export CSV for review?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Export CSV'),
              ),
            ],
          ),
        );
        if (export == true) {
          await _exportFailedRowsCsv(failedRows, isPreview: isPreview);
        }
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  List<Map<String, dynamic>> _extractFailedRows(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final raw = data['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['ok'] != true)
        .toList();
  }

  Future<void> _exportFailedRowsCsv(
    List<Map<String, dynamic>> failedRows, {
    required bool isPreview,
  }) async {
    final rows = <List<dynamic>>[
      ['refillId', 'code', 'error', 'mode', 'exportedAt'],
      ...failedRows.map(
        (r) => [
          r['refillId']?.toString() ?? '',
          r['code']?.toString() ?? '',
          r['error']?.toString() ?? '',
          isPreview ? 'preview' : 'apply',
          DateTime.now().toIso8601String(),
        ],
      ),
    ];
    final csv = CsvCodec().encode(rows);
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/refill-backfill-failures-$stamp.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Refill backfill failed rows CSV',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refill Data Repair'),
        actions: [
          IconButton(
            onPressed: _loading || _updating ? null : _bulkFixPrescribedQty,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Bulk fix prescribed qty using requested qty',
          ),
          IconButton(
            onPressed: _loading || _updating ? null : _loadIncomplete,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload incomplete rows',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadIncomplete,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_incompleteItems.isEmpty) {
      return const Center(
        child: Text('No incomplete legacy refill rows'),
      );
    }

    return ListView.separated(
      itemCount: _incompleteItems.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _incompleteItems.length) {
          if (!_hasMore) return const SizedBox(height: 12);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _updating ? null : _loadMoreIncomplete,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        final item = _incompleteItems[index];
        final status = item['status']?.toString() ?? 'requested';
        final missingProduct =
            item['productId'] == null || (item['productId'] as String).trim().isEmpty;
        final missingPrescribed = item['prescribedQty'] == null ||
            (item['prescribedQty'] as num?)?.toInt() == 0;

        return ListTile(
          title:
              Text('${item['patientName'] ?? 'Unknown'} • ${item['drugName'] ?? ''}'),
          subtitle: Text(
            'Rx: ${item['prescriptionId'] ?? '-'} | Qty: ${item['requestedQty'] ?? 0}/${item['prescribedQty'] ?? 0} | Status: $status',
          ),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (missingProduct)
                const Chip(
                  label: Text('Missing productId'),
                  visualDensity: VisualDensity.compact,
                ),
              if (missingPrescribed)
                const Chip(
                  label: Text('Missing prescribedQty'),
                  visualDensity: VisualDensity.compact,
                ),
              OutlinedButton.icon(
                onPressed: _updating ? null : () => _backfillTrace(item),
                icon: const Icon(Icons.build, size: 16),
                label: const Text('Backfill'),
              ),
            ],
          ),
        );
      },
    );
  }
}
