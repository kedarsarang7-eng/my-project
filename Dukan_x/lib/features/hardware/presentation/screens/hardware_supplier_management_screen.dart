import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HardwareSupplierManagementScreen extends StatefulWidget {
  const HardwareSupplierManagementScreen({super.key});

  @override
  State<HardwareSupplierManagementScreen> createState() =>
      _HardwareSupplierManagementScreenState();
}

class _HardwareSupplierManagementScreenState
    extends State<HardwareSupplierManagementScreen> {
  // Localized rupee symbol (bugfix.md 2.20) — render '₹' instead of 'Rs '.
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _searchCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _openingCtrl = TextEditingController(text: '0');
  final _paymentTermCtrl = TextEditingController(text: '30');
  final _notesCtrl = TextEditingController();

  ApiClient get _api => sl<ApiClient>();

  bool _loading = true;
  List<Map<String, dynamic>> _suppliers = const [];
  Map<String, dynamic> _totals = const {};
  Map<String, dynamic> _ageing = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    _openingCtrl.dispose();
    _paymentTermCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final listRes = await _api.get(
      '/suppliers',
      queryParameters: {
        if (_searchCtrl.text.trim().isNotEmpty)
          'search': _searchCtrl.text.trim(),
        'limit': '200',
        'page': '1',
      },
    );
    final summaryRes = await _api.get('/suppliers/payables/summary');
    final ageingRes = await _api.get('/suppliers/payables/ageing');
    if (!mounted) return;

    if (!listRes.isSuccess) {
      setState(() => _loading = false);
      _notify(listRes.error ?? 'Suppliers load failed');
      return;
    }
    final listData = (listRes.data?['data'] ?? const []) as List;
    Map<String, dynamic> totals = const {};
    if (summaryRes.isSuccess) {
      final summaryData = (summaryRes.data?['data'] ?? const {}) as Map;
      totals = Map<String, dynamic>.from(
        (summaryData['totals'] as Map?) ?? const {},
      );
    }
    Map<String, dynamic> ageing = const {};
    if (ageingRes.isSuccess) {
      final ageingData = (ageingRes.data?['data'] ?? const {}) as Map;
      ageing = Map<String, dynamic>.from(
        (ageingData['buckets'] as Map?) ?? const {},
      );
    }
    setState(() {
      _suppliers = listData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _totals = totals;
      _ageing = ageing;
      _loading = false;
    });
  }

  Future<void> _createSupplier() async {
    if (!_formKey.currentState!.validate()) return;
    final openingRs = double.tryParse(_openingCtrl.text.trim()) ?? 0;
    final termDays = int.tryParse(_paymentTermCtrl.text.trim()) ?? 30;

    final res = await _api.post(
      '/suppliers',
      body: {
        'name': _nameCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_gstinCtrl.text.trim().isNotEmpty) 'gstin': _gstinCtrl.text.trim(),
        'openingBalance': (openingRs * 100).round(),
        'paymentTermDays': termDays,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      },
    );

    if (!mounted) return;
    if (!res.isSuccess) {
      _notify(res.error ?? 'Supplier create failed');
      return;
    }
    Navigator.of(context).pop();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _gstinCtrl.clear();
    _openingCtrl.text = '0';
    _paymentTermCtrl.text = '30';
    _notesCtrl.clear();
    _notify('Supplier created');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Supplier Management'),
        actions: [
          OutlinedButton.icon(
            onPressed: _suppliers.isEmpty ? null : _exportSuppliersCsv,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export CSV'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _triggerRemindersDialog,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Reminders'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Supplier'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : DesktopContentContainer(
                maxWidth: 1600,
                child: Column(
                  children: [
                    _buildSearchAndKpi(),
                    const SizedBox(height: 10),
                    _buildAgeingStrip(),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _suppliers.isEmpty
                          ? const Center(
                              child: Text('No supplier records found'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _suppliers.length,
                              itemBuilder: (context, i) =>
                                  _buildSupplierCard(_suppliers[i]),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _exportSuppliersCsv() async {
    try {
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
      final rows = <String>[
        'Supplier,Phone,GSTIN,OpeningPayableRs,OutstandingPayableRs,TermDays',
      ];
      String esc(String v) => '"${v.replaceAll('"', '""')}"';
      for (final s in _suppliers) {
        final opening = ((s['openingBalance'] as num?)?.toDouble() ?? 0) / 100;
        final outstanding =
            ((s['outstandingPayableCents'] as num?)?.toDouble() ?? 0) / 100;
        rows.add(
          [
            esc((s['name'] ?? '').toString()),
            esc((s['phone'] ?? '').toString()),
            esc((s['gstin'] ?? '').toString()),
            opening.toStringAsFixed(2),
            outstanding.toStringAsFixed(2),
            ((s['paymentTermDays'] as num?)?.toInt() ?? 0).toString(),
          ].join(','),
        );
      }
      final csv = '${rows.join('\n')}\n';
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}exports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final filePath =
          '${dir.path}${Platform.pathSeparator}hardware_suppliers_$ts.csv';
      await File(filePath).writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported: $filePath'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _notify('CSV export failed: $e');
    }
  }

  Future<void> _triggerRemindersDialog() async {
    final minAgeCtrl = TextEditingController(text: '30');
    final minAmtCtrl = TextEditingController(text: '1000');
    final quietStartCtrl = TextEditingController(text: '22');
    final quietEndCtrl = TextEditingController(text: '7');
    bool dryRun = true;
    bool whatsapp = true;
    bool email = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Trigger Supplier Reminders'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: minAgeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min age days',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minAmtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min outstanding (cents)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: dryRun,
                  onChanged: (v) => setLocal(() => dryRun = v),
                  title: const Text('Dry run'),
                  subtitle: const Text(
                    'If off, sends WhatsApp text where phone exists',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: whatsapp,
                  onChanged: (v) => setLocal(() => whatsapp = v ?? false),
                  title: const Text('WhatsApp'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: email,
                  onChanged: (v) => setLocal(() => email = v ?? false),
                  title: const Text('Email'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quietStartCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quiet start (0-23)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: quietEndCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quiet end (0-23)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final minAge = int.tryParse(minAgeCtrl.text.trim()) ?? 30;
    final minOutstandingCents = int.tryParse(minAmtCtrl.text.trim()) ?? 1000;
    final quietStart = int.tryParse(quietStartCtrl.text.trim()) ?? 22;
    final quietEnd = int.tryParse(quietEndCtrl.text.trim()) ?? 7;
    final channels = <String>[if (whatsapp) 'whatsapp', if (email) 'email'];
    if (channels.isEmpty) {
      _notify('Select at least one channel');
      return;
    }
    final res = await _api.post(
      '/suppliers/payables/reminders/trigger',
      body: {
        'minAgeDays': minAge,
        'minOutstandingCents': minOutstandingCents,
        'dryRun': dryRun,
        'channels': channels,
        'quietHoursStart': quietStart,
        'quietHoursEnd': quietEnd,
      },
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      _notify(res.error ?? 'Reminder trigger failed');
      return;
    }
    final data = (res.data?['data'] ?? const {}) as Map;
    final candidates = (data['candidates'] as num?)?.toInt() ?? 0;
    final sent = (data['sent'] as num?)?.toInt() ?? 0;
    _notify(
      dryRun
          ? 'Dry-run complete. Candidates: $candidates'
          : 'Reminder run complete. Candidates: $candidates, sent: $sent',
    );
  }

  Widget _buildSearchAndKpi() {
    final supplierCount =
        (_totals['supplierCount'] as num?)?.toInt() ?? _suppliers.length;
    final totalOutstanding =
        (_totals['totalOutstandingPayableCents'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search supplier by name / phone / GSTIN',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _load,
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Suppliers',
                  '$supplierCount',
                  Icons.storefront_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Outstanding Payable',
                  _currency.format(totalOutstanding / 100),
                  Icons.account_balance_wallet_outlined,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeingStrip() {
    final current = ((_ageing['current'] as num?)?.toDouble() ?? 0) / 100;
    final b30 = ((_ageing['d1to30'] as num?)?.toDouble() ?? 0) / 100;
    final b60 = ((_ageing['d31to60'] as num?)?.toDouble() ?? 0) / 100;
    final b90 = ((_ageing['d61to90'] as num?)?.toDouble() ?? 0) / 100;
    final b90p = ((_ageing['d90plus'] as num?)?.toDouble() ?? 0) / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ageChip('Current', current, Colors.blueGrey),
          _ageChip('1-30d', b30, Colors.blue),
          _ageChip('31-60d', b60, Colors.orange),
          _ageChip('61-90d', b90, Colors.deepOrange),
          _ageChip('90d+', b90p, Colors.red),
        ],
      ),
    );
  }

  Widget _ageChip(String label, double value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.schedule, color: color, size: 14),
      ),
      label: Text('$label  ${_currency.format(value)}'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
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
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
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

  Widget _buildSupplierCard(Map<String, dynamic> s) {
    final name = (s['name'] ?? '').toString();
    final phone = (s['phone'] ?? '').toString();
    final gstin = (s['gstin'] ?? '').toString();
    final payable =
        ((s['outstandingPayableCents'] as num?)?.toDouble() ?? 0) / 100;
    final opening = ((s['openingBalance'] as num?)?.toDouble() ?? 0) / 100;
    final termDays = (s['paymentTermDays'] as num?)?.toInt() ?? 0;
    final supplierId = (s['id'] ?? '').toString();

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
                    name.isEmpty ? 'Unnamed supplier' : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Chip(
                  label: Text(termDays > 0 ? '$termDays d term' : 'No term'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (phone.isNotEmpty || gstin.isNotEmpty)
              Text(
                [
                  if (phone.isNotEmpty) phone,
                  if (gstin.isNotEmpty) gstin,
                ].join('  •  '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Opening: ${_currency.format(opening)}')),
                Text(
                  _currency.format(payable),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: payable > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: supplierId.isEmpty
                      ? null
                      : () => _showLedgerDialog(
                          supplierId: supplierId,
                          supplierName: name,
                        ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('View Ledger'),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: payable <= 0 || supplierId.isEmpty
                      ? null
                      : () => _showRecordPaymentDialog(
                          supplierId: supplierId,
                          supplierName: name,
                          maxPayableRs: payable,
                        ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record Payment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLedgerDialog({
    required String supplierId,
    required String supplierName,
  }) async {
    final res = await _api.get(
      '/suppliers/$supplierId/ledger',
      queryParameters: {'limit': '250'},
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      _notify(res.error ?? 'Ledger load failed');
      return;
    }
    final data = (res.data?['data'] ?? const {}) as Map;
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final totals = Map<String, dynamic>.from(
      (data['totals'] as Map?) ?? const {},
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ledger - $supplierName'),
        content: SizedBox(
          width: 860,
          height: 520,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'Purchase ${_currency.format(((totals['totalPurchaseCents'] as num?)?.toDouble() ?? 0) / 100)}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Paid ${_currency.format(((totals['totalPaid'] as num?)?.toDouble() ?? 0) / 100)}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Outstanding ${_currency.format(((totals['outstandingPayableCents'] as num?)?.toDouble() ?? 0) / 100)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No ledger entries'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, dividerIndex) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = items[i];
                          final type = (row['type'] ?? '').toString();
                          final date = (row['date'] ?? '').toString();
                          final ref = (row['referenceNo'] ?? '-').toString();
                          final debit =
                              ((row['debitCents'] as num?)?.toDouble() ?? 0) /
                              100;
                          final credit =
                              ((row['creditCents'] as num?)?.toDouble() ?? 0) /
                              100;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              type == 'payment'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.receipt_long_outlined,
                              color: type == 'payment'
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                            title: Text(ref),
                            subtitle: Text(date),
                            trailing: SizedBox(
                              width: 230,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 105,
                                    child: Text(
                                      debit > 0 ? _currency.format(debit) : '-',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 105,
                                    child: Text(
                                      credit > 0
                                          ? _currency.format(credit)
                                          : '-',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordPaymentDialog({
    required String supplierId,
    required String supplierName,
    required double maxPayableRs,
  }) async {
    final amountCtrl = TextEditingController(
      text: maxPayableRs.toStringAsFixed(2),
    );
    String mode = 'cash';
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Payment - $supplierName'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        'Amount (Rs) <= ${maxPayableRs.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(
                    labelText: 'Payment mode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (v) => setLocal(() => mode = v ?? mode),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference no.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final amtRs = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amtRs <= 0 || amtRs > maxPayableRs + 0.0001) {
      _notify('Invalid payment amount');
      return;
    }

    final res = await _api.post(
      '/suppliers/payments',
      body: {
        'supplierId': supplierId,
        'amountCents': (amtRs * 100).round(),
        'paymentMode': mode,
        if (refCtrl.text.trim().isNotEmpty) 'referenceNo': refCtrl.text.trim(),
        if (noteCtrl.text.trim().isNotEmpty) 'notes': noteCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      _notify(res.error ?? 'Payment record failed');
      return;
    }
    _notify('Supplier payment recorded');
    _load();
  }

  Future<void> _showCreateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Supplier'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(_nameCtrl, 'Supplier Name *', required: true),
                  _field(_phoneCtrl, 'Phone'),
                  _field(_gstinCtrl, 'GSTIN'),
                  _field(
                    _openingCtrl,
                    'Opening Payable (Rs)',
                    keyboard: TextInputType.number,
                  ),
                  _field(
                    _paymentTermCtrl,
                    'Payment Term (days)',
                    keyboard: TextInputType.number,
                  ),
                  _field(_notesCtrl, 'Notes'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createSupplier,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
