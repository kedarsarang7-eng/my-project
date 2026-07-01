import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HardwareCreditControlScreen extends StatefulWidget {
  const HardwareCreditControlScreen({super.key});

  @override
  State<HardwareCreditControlScreen> createState() =>
      _HardwareCreditControlScreenState();
}

class _HardwareCreditControlScreenState
    extends State<HardwareCreditControlScreen> {
  // Localized rupee symbol (bugfix.md 2.20) — render '₹' instead of 'Rs '.
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  bool _loading = true;
  int _minAgeDays = 15;
  int _minBalanceRs = 1;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _totals = const {};

  ApiClient get _api => sl<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get(
      '/customers/credit/reminder-candidates',
      queryParameters: {
        'minAgeDays': _minAgeDays.toString(),
        'minBalanceCents': (_minBalanceRs * 100).toString(),
      },
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      setState(() {
        _items = const [];
        _totals = const {};
        _loading = false;
      });
      _notify(res.error ?? 'Credit candidates load failed');
      return;
    }

    final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>?;
    final itemsRaw = data?['items'];
    final totalsRaw = data?['totals'];
    setState(() {
      _items = itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [];
      _totals = totalsRaw is Map
          ? Map<String, dynamic>.from(totalsRaw)
          : const {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Credit Control'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildFilters(),
                  _buildSummary(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No overdue contractor/customer credit matches filters.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, i) =>
                                _buildCreditCard(_items[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _smallDropdown<int>(
            label: 'Min Age',
            value: _minAgeDays,
            values: const [7, 15, 30, 45, 60, 90],
            format: (v) => '$v days',
            onChanged: (v) {
              if (v == null) return;
              setState(() => _minAgeDays = v);
              _load();
            },
          ),
          _smallDropdown<int>(
            label: 'Min Balance',
            value: _minBalanceRs,
            values: const [1, 500, 1000, 2500, 5000, 10000],
            format: (v) => '₹$v',
            onChanged: (v) {
              if (v == null) return;
              setState(() => _minBalanceRs = v);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _smallDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) format,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        items: values
            .map((v) => DropdownMenuItem<T>(value: v, child: Text(format(v))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSummary() {
    final parties = (_totals['partyCount'] as num?)?.toInt() ?? _items.length;
    final outstandingCents =
        (_totals['totalOutstanding'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              'Parties',
              '$parties',
              Icons.people_outline,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricCard(
              'Total Overdue',
              _currency.format(outstandingCents / 100),
              Icons.warning_amber_outlined,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> item) {
    final name = (item['customerName'] ?? 'Unknown').toString();
    final phone = (item['phone'] ?? '').toString();
    final outstanding =
        ((item['outstandingCents'] as num?)?.toDouble() ?? 0) / 100;
    final openCount = (item['openInvoiceCount'] as num?)?.toInt() ?? 0;
    final maxAge = (item['oldestOpenInvoiceAgeDays'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text('${maxAge.toStringAsFixed(0)}d old'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (phone.isNotEmpty)
              Text(phone, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Open invoices: $openCount')),
                Text(
                  _currency.format(outstanding),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
