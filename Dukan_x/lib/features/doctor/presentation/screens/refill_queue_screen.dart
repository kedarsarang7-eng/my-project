import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RefillQueueScreen extends StatefulWidget {
  const RefillQueueScreen({super.key});

  @override
  State<RefillQueueScreen> createState() => _RefillQueueScreenState();
}

class _RefillQueueScreenState extends State<RefillQueueScreen> {
  final ApiClient _api = sl<ApiClient>();
  bool _loading = true;
  bool _loadingMore = false;
  bool _updating = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  String? _selectedStatus = 'requested';
  String? _nextCursor;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/pharmacy/prescriptions/refills?${_selectedStatus == null ? '' : 'status=$_selectedStatus&'}page=1&pageSize=50',
      );
      if (!res.isSuccess || res.data == null) {
        setState(() {
          _error = res.error ?? 'Failed to load refill queue';
          _loading = false;
        });
        return;
      }
      final data = Map<String, dynamic>.from(res.data!);
      final rows = List<Map<String, dynamic>>.from(data['data'] ?? const []);
      final meta = Map<String, dynamic>.from(data['meta'] ?? const {});
      setState(() {
        _items = rows;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _api.get(
        '/pharmacy/prescriptions/refills?${_selectedStatus == null ? '' : 'status=$_selectedStatus&'}cursor=${Uri.encodeComponent(_nextCursor!)}&pageSize=50',
      );
      if (!res.isSuccess || res.data == null) return;
      final data = Map<String, dynamic>.from(res.data!);
      final rows = List<Map<String, dynamic>>.from(data['data'] ?? const []);
      final meta = Map<String, dynamic>.from(data['meta'] ?? const {});
      setState(() {
        _items = [..._items, ...rows];
        _nextCursor = meta['nextCursor']?.toString();
        _hasMore = meta['hasMore'] == true;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _transition(
    String id,
    String status, {
    String? reason,
    String? invoiceId,
    int? dispensedQty,
  }) async {
    setState(() => _updating = true);
    try {
      final res = await _api.post(
        '/pharmacy/prescriptions/refills/$id/status',
        body: {
          'status': status,
          ...{'reason': reason?.isNotEmpty == true ? reason : null},
          ...{'invoiceId': invoiceId?.isNotEmpty == true ? invoiceId : null},
          ...{'dispensedQty': dispensedQty},
        },
      );
      if (!res.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Failed to update status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        await _load();
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _rejectWithReason(String id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Refill'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Out of stock / invalid request / doctor review needed',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _transition(id, 'rejected', reason: reason);
  }

  Future<void> _dispenseWithInvoice(Map<String, dynamic> item) async {
    final invoiceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(
      text: (item['requestedQty'] ?? 0).toString(),
    );

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dispense Refill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: invoiceCtrl,
              decoration: const InputDecoration(
                labelText: 'Invoice ID',
                hintText: 'Required for dispensing trace',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dispensed Qty',
              ),
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
            child: const Text('Mark Dispensed'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    final invoiceId = invoiceCtrl.text.trim();
    final prescribedQty =
        (item['prescribedQty'] as num?)?.toInt() ??
            (item['requestedQty'] as num?)?.toInt() ??
            0;
    final dispensedQty = int.tryParse(qtyCtrl.text.trim()) ?? prescribedQty;
    final productId = item['productId']?.toString().trim();
    if (invoiceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice ID required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (dispensedQty < prescribedQty &&
        (productId == null || productId.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Product ID missing on refill request. Cannot record partial fill.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _updating = true);
    try {
      if (dispensedQty < prescribedQty) {
        final partialRes = await _api.post(
          '/pharmacy/prescriptions/partial-fills',
          body: {
            'prescriptionId': item['prescriptionId']?.toString() ?? '',
            'invoiceId': invoiceId,
            'productId': productId,
            'productName': item['drugName']?.toString() ?? 'Unknown Drug',
            'prescribedQty': prescribedQty,
            'dispensedQty': dispensedQty,
            'reason': 'Partial dispense from refill queue',
          },
        );
        if (!partialRes.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(partialRes.error ?? 'Failed to record partial fill'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      await _transition(
        item['id']?.toString() ?? '',
        'dispensed',
        invoiceId: invoiceId,
        dispensedQty: dispensedQty,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refill Queue'),
        actions: [
          DropdownButton<String?>(
            value: _selectedStatus,
            underline: const SizedBox.shrink(),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: const [
              DropdownMenuItem(value: 'requested', child: Text('Requested')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              DropdownMenuItem(value: 'dispensed', child: Text('Dispensed')),
              DropdownMenuItem(value: null, child: Text('All')),
            ],
            onChanged: _loading || _updating
                ? null
                : (v) {
                    setState(() => _selectedStatus = v);
                    _load();
                  },
          ),
          IconButton(
            onPressed: _loading || _updating ? null : _load,
            icon: const Icon(Icons.refresh),
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
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final visibleItems = _items;

    if (visibleItems.isEmpty) {
      return Center(
        child: Text(
          _selectedStatus == null
              ? 'No refill requests'
              : 'No ${_selectedStatus!} refill requests',
        ),
      );
    }

    return ListView.separated(
      itemCount: visibleItems.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == visibleItems.length) {
          if (!_hasMore) return const SizedBox(height: 12);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _updating ? null : _loadMore,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        final item = visibleItems[index];
        final id = item['id']?.toString() ?? '';
        final status = item['status']?.toString() ?? 'requested';
        return ListTile(
          title: Text('${item['patientName'] ?? 'Unknown'} • ${item['drugName'] ?? ''}'),
          subtitle: Text(
            'Rx: ${item['prescriptionId'] ?? '-'} | Qty: ${item['requestedQty'] ?? 0}/${item['prescribedQty'] ?? item['requestedQty'] ?? 0} | Status: $status',
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              if (status == 'requested') ...[
                OutlinedButton(
                  onPressed: _updating ? null : () => _rejectWithReason(id),
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: _updating ? null : () => _transition(id, 'approved'),
                  child: const Text('Approve'),
                ),
              ] else if (status == 'approved') ...[
                ElevatedButton.icon(
                  onPressed: _updating ? null : () => _dispenseWithInvoice(item),
                  icon: const Icon(Icons.local_pharmacy, size: 16),
                  label: const Text('Dispense'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
