import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/hardware_ops_repository.dart';
import '../../../barcode/widgets/desktop_usb_scanner.dart';
import '../../../barcode/services/barcode_lookup_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HardwareOperationsScreen extends StatefulWidget {
  final int initialTab;
  final String? initialDepositStatus;

  const HardwareOperationsScreen({
    super.key,
    this.initialTab = 0,
    this.initialDepositStatus,
  });

  @override
  State<HardwareOperationsScreen> createState() =>
      _HardwareOperationsScreenState();
}

class _HardwareOperationsScreenState extends State<HardwareOperationsScreen>
    with SingleTickerProviderStateMixin {
  static const _depositFilterPrefKey = 'hardware_deposit_status_filter';
  static const _tabIndexPrefKey = 'hardware_operations_tab_index';
  // Allow only digits and a single decimal point for numeric inputs
  // (bugfix.md 2.21). Letters/symbols are rejected as the user types.
  static final List<TextInputFormatter> _numericInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  ];
  final _repo = HardwareOpsRepository();
  // Localized rupee symbol (bugfix.md 2.20) — render '₹' instead of 'Rs '.
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  late final TabController _tabController;
  String _ownerScope = 'anonymous';

  bool _loading = true;
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _indents = const [];
  List<Map<String, dynamic>> _deposits = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _products = const [];
  String? _depositStatusFilter;

  @override
  void initState() {
    super.initState();
    _ownerScope = sl<SessionManager>().ownerId ?? 'anonymous';
    final hasDeepLinkTab = widget.initialTab > 0;
    final initialIndex = widget.initialTab.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _persistTabIndex(_tabController.index);
        if (mounted) setState(() {});
      }
    });

    if (!hasDeepLinkTab) {
      _loadPersistedTabIndex();
    } else {
      _persistTabIndex(initialIndex);
    }

    if (widget.initialDepositStatus != null &&
        widget.initialDepositStatus!.isNotEmpty) {
      _depositStatusFilter = widget.initialDepositStatus;
      _persistDepositFilter(_depositStatusFilter);
    } else {
      _loadPersistedDepositFilter();
    }
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanProductBarcode() async {
    final barcode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Scan Hardware Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan barcode to look up product details for indent/project.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DesktopUsbScanner(
                onProductScanned: (product) =>
                    Navigator.pop(ctx, product.barcode),
                onProductNotFound: (code) => Navigator.pop(ctx, code),
              ),
            ],
          ),
        ),
      ),
    );

    if (barcode == null || barcode.isEmpty) return;

    try {
      final lookupService = sl<BarcodeLookupService>();
      await lookupService.initialize();
      final lookupResult = await lookupService.lookupBarcode(
        barcode: barcode,
        businessId: sl<SessionManager>().currentBusinessId,
      );

      final repo = sl<ProductsRepository>();
      final productsResult = await repo.search(barcode, userId: _ownerScope);
      final products = productsResult.data ?? [];

      final productName = products.isNotEmpty
          ? products
                .firstWhere(
                  (p) =>
                      p.barcode == barcode || p.altBarcodes.contains(barcode),
                  orElse: () => products.first,
                )
                .name
          : (lookupResult.product?.name ?? barcode);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Product Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: $productName'),
                if (lookupResult.product != null) ...[
                  Text('Barcode: $barcode'),
                  if (lookupResult.product!.brand != null)
                    Text('Brand: ${lookupResult.product!.brand}'),
                ],
                const SizedBox(height: 8),
                // Stock status with a text + semantic companion (bugfix.md
                // 2.24): status is not conveyed by colour alone — an explicit
                // label, an icon, and a Semantics description accompany it.
                Builder(
                  builder: (context) {
                    final inInventory = products.isNotEmpty;
                    final statusLabel = inInventory
                        ? 'In stock'
                        : 'Not in inventory';
                    final detail = inInventory
                        ? 'Stock: ${products.first.stockQuantity ?? 0} ${products.first.unit ?? ''}'
                        : 'Not in local inventory';
                    final color = inInventory ? Colors.green : Colors.orange;
                    return Semantics(
                      label: '$statusLabel. $detail',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            inInventory
                                ? Icons.check_circle
                                : Icons.warning_amber,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$statusLabel · $detail',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
              if (_tabController.index == 1)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateIndentDialog(prefillProductName: productName);
                  },
                  child: const Text('Add to Indent'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    final errors = <String>[];

    // Offline/error fallback (bugfix.md 2.16): on a failed fetch we keep the
    // last successfully-loaded values (a local in-memory cache) instead of
    // clearing the tab to an empty list.
    Future<List<Map<String, dynamic>>> safe(
      String label,
      Future<List<Map<String, dynamic>>> Function() op,
      List<Map<String, dynamic>> cached,
    ) async {
      try {
        return await op();
      } on HardwareOpsException catch (e) {
        errors.add('$label: ${e.message}');
        return cached;
      } catch (e) {
        errors.add('$label: $e');
        return cached;
      }
    }

    // Run the five independent fetches CONCURRENTLY (bugfix.md 2.16) via
    // Future.wait rather than awaiting them one-by-one, so a refresh is bound by
    // the slowest call instead of the sum of all five.
    final results = await Future.wait<List<Map<String, dynamic>>>([
      safe('Projects', () => _repo.listProjects(), _projects),
      safe('Indents', () => _repo.listIndents(), _indents),
      safe(
        'Deposits',
        () => _repo.listDeposits(status: _depositStatusFilter),
        _deposits,
      ),
      safe('Customers', () => _repo.listCustomers(), _customers),
      safe('Products', () => _repo.listProducts(), _products),
    ]);

    if (!mounted) return;
    setState(() {
      _projects = results[0];
      _indents = results[1];
      _deposits = results[2];
      _customers = results[3];
      _products = results[4];
      _loading = false;
    });

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some sections may be showing cached data (refresh failed):\n'
            '${errors.join('\n')}',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Hardware Operations',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    _hardwareBadgeLabel(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan product barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProductBarcode,
          ),
          IconButton(
            tooltip: 'Reset Filters',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: _resetFilters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Projects'),
            Tab(text: 'Indents'),
            Tab(text: 'Deposits'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildProjectsTab(),
                  _buildIndentsTab(),
                  _buildDepositsTab(),
                ],
              ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          switch (_tabController.index) {
            case 0:
              await _showCreateProjectDialog();
              break;
            case 1:
              await _showCreateIndentDialog();
              break;
            default:
              await _showCreateDepositDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) return _empty('No hardware projects');
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          final status = (project['status'] ?? 'active').toString();
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text((project['projectName'] ?? 'Untitled').toString()),
              subtitle: Text(
                'Contractor: ${(project['contractorName'] ?? '-')} | Site: ${(project['siteAddress'] ?? '-')}',
              ),
              trailing: status == 'closed'
                  ? const Chip(label: Text('Closed'))
                  : TextButton(
                      onPressed: () async {
                        try {
                          await _repo.closeProject(project['id'].toString());
                          _notify('Project closed');
                          await _refreshAll();
                        } on HardwareOpsException catch (e) {
                          _notify('Failed to close project: ${e.message}');
                        }
                      },
                      child: const Text('Close'),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIndentsTab() {
    if (_indents.isEmpty) return _empty('No indents');
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _indents.length,
        itemBuilder: (context, index) {
          final indent = _indents[index];
          final status = (indent['status'] ?? 'open').toString();
          final items = (indent['items'] as List?) ?? const [];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text('Requested by: ${(indent['requestedBy'] ?? '-')}'),
              subtitle: Text(
                'Priority: ${(indent['priority'] ?? 'normal')} | Items: ${items.length}',
              ),
              trailing: status == 'closed'
                  ? const Chip(label: Text('Closed'))
                  : TextButton(
                      onPressed: () async {
                        try {
                          await _repo.closeIndent(indent['id'].toString());
                          _notify('Indent closed');
                          await _refreshAll();
                        } on HardwareOpsException catch (e) {
                          _notify('Failed to close indent: ${e.message}');
                        }
                      },
                      child: const Text('Close'),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepositsTab() {
    if (_deposits.isEmpty) return _empty('No deposits');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _depositStatusFilter == null,
                onSelected: (_) async {
                  await _setDepositFilter(null);
                  await _refreshAll();
                },
              ),
              ChoiceChip(
                label: const Text('Open'),
                selected: _depositStatusFilter == 'open',
                onSelected: (_) async {
                  await _setDepositFilter('open');
                  await _refreshAll();
                },
              ),
              ChoiceChip(
                label: const Text('Closed'),
                selected: _depositStatusFilter == 'closed',
                onSelected: (_) async {
                  await _setDepositFilter('closed');
                  await _refreshAll();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView.builder(
              itemCount: _deposits.length,
              itemBuilder: (context, index) {
                final dep = _deposits[index];
                final status = (dep['status'] ?? 'open').toString();
                final outstandingCents =
                    (dep['outstandingDepositCents'] as num?)?.toDouble() ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(
                      '${dep['customerName'] ?? 'Customer'} - ${dep['itemType'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Qty: ${dep['quantity'] ?? 0} | Outstanding: ${_currency.format(outstandingCents / 100)}',
                    ),
                    trailing: status == 'closed'
                        ? const Chip(label: Text('Closed'))
                        : TextButton(
                            onPressed: () => _showSettleDepositDialog(dep),
                            child: const Text('Settle'),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(String label) => Center(child: Text(label));

  Future<void> _showCreateProjectDialog() async {
    final name = TextEditingController();
    final contractor = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();
    final submit = await _showFormDialog(
      title: 'Create Project',
      fields: [
        _field(name, 'Project name *'),
        _field(contractor, 'Contractor name'),
        _field(address, 'Site address'),
        _field(notes, 'Notes'),
      ],
    );
    if (submit != true || name.text.trim().isEmpty) return;
    try {
      await _repo.createProject(
        projectName: name.text.trim(),
        contractorName: contractor.text,
        siteAddress: address.text,
        notes: notes.text,
      );
      _notify('Project created');
      await _refreshAll();
    } on HardwareOpsException catch (e) {
      _notify('Project create failed: ${e.message}');
    }
  }

  Future<void> _showCreateIndentDialog({String? prefillProductName}) async {
    if (_projects.isEmpty) {
      _notify('Create project first');
      return;
    }
    if (_products.isEmpty) {
      _notify('No products found in inventory');
      return;
    }
    String selectedProjectId = _projects.first['id'].toString();
    // Pre-select product matching scanned name if provided
    String selectedProductId = prefillProductName != null
        ? _products
              .firstWhere(
                (p) =>
                    (p['name'] ?? '').toString().toLowerCase() ==
                    prefillProductName.toLowerCase(),
                orElse: () => _products.first,
              )['id']
              .toString()
        : _products.first['id'].toString();
    final requestedBy = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final notes = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Indent'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProjectId,
                  items: _projects
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(
                            (p['projectName'] ?? 'Project').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(
                    () => selectedProjectId = v ?? selectedProjectId,
                  ),
                  decoration: const InputDecoration(labelText: 'Project *'),
                ),
                _field(requestedBy, 'Requested by *'),
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  items: _products
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text((p['name'] ?? 'Product').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(
                    () => selectedProductId = v ?? selectedProductId,
                  ),
                  decoration: const InputDecoration(labelText: 'Product *'),
                ),
                _field(
                  quantity,
                  'Quantity *',
                  keyboardType: TextInputType.number,
                ),
                _field(notes, 'Notes'),
              ],
            ),
          ),
        ),
        actions: _dialogActions(),
      ),
    );
    if (submit != true || requestedBy.text.trim().isEmpty) {
      return;
    }

    final qty = double.tryParse(quantity.text.trim()) ?? 0;
    if (qty <= 0) {
      _notify('Quantity invalid');
      return;
    }

    final selectedProduct = _products.firstWhere(
      (p) => p['id'].toString() == selectedProductId,
      orElse: () => const {},
    );
    final itemName = (selectedProduct['name'] ?? 'Item').toString();

    try {
      await _repo.createIndent(
        projectId: selectedProjectId,
        requestedBy: requestedBy.text.trim(),
        items: [
          {
            'productId': selectedProductId,
            'name': itemName,
            'quantity': qty,
            'unit': (selectedProduct['unit'] ?? 'pcs').toString(),
          },
        ],
        notes: notes.text,
      );
      _notify('Indent created');
      await _refreshAll();
    } on HardwareOpsException catch (e) {
      _notify('Indent create failed: ${e.message}');
    }
  }

  Future<void> _showCreateDepositDialog() async {
    if (_customers.isEmpty) {
      _notify('No customers found');
      return;
    }
    String selectedCustomerId = _customers.first['id'].toString();
    final itemType = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final amount = TextEditingController();
    final refNo = TextEditingController();
    final notes = TextEditingController();
    final submit = await _showFormDialog(
      title: 'Create Deposit',
      fields: [
        DropdownButtonFormField<String>(
          value: selectedCustomerId,
          items: _customers
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text((c['name'] ?? 'Customer').toString()),
                ),
              )
              .toList(),
          onChanged: (v) => selectedCustomerId = v ?? selectedCustomerId,
          decoration: const InputDecoration(
            labelText: 'Customer *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _field(itemType, 'Item type *'),
        _field(quantity, 'Quantity *', keyboardType: TextInputType.number),
        _field(
          amount,
          'Deposit amount (₹) *',
          keyboardType: TextInputType.number,
        ),
        _field(refNo, 'Reference number'),
        _field(notes, 'Notes'),
      ],
    );
    if (submit != true) return;
    final qty = double.tryParse(quantity.text.trim()) ?? 0;
    final amountRupees = double.tryParse(amount.text.trim()) ?? 0;
    if (qty <= 0 || amountRupees <= 0 || itemType.text.trim().isEmpty) {
      _notify('Deposit fields invalid');
      return;
    }
    final selectedCustomer = _customers.firstWhere(
      (c) => c['id'].toString() == selectedCustomerId,
      orElse: () => const {},
    );
    try {
      await _repo.createDeposit(
        customerId: selectedCustomerId,
        customerName: (selectedCustomer['name'] ?? '').toString(),
        itemType: itemType.text.trim(),
        quantity: qty,
        depositAmountCents: (amountRupees * 100).round(),
        referenceNo: refNo.text,
        notes: notes.text,
      );
      _notify('Deposit created');
      await _refreshAll();
    } on HardwareOpsException catch (e) {
      _notify('Deposit create failed: ${e.message}');
    }
  }

  Future<void> _showSettleDepositDialog(Map<String, dynamic> dep) async {
    final returnedQty = TextEditingController(text: '1');
    final refund = TextEditingController();
    final notes = TextEditingController();
    final submit = await _showFormDialog(
      title: 'Settle Deposit',
      fields: [
        _field(
          returnedQty,
          'Returned quantity *',
          keyboardType: TextInputType.number,
        ),
        _field(
          refund,
          'Refund amount (₹) *',
          keyboardType: TextInputType.number,
        ),
        _field(notes, 'Notes'),
      ],
    );
    if (submit != true) return;
    final qty = double.tryParse(returnedQty.text.trim()) ?? 0;
    final refundRs = double.tryParse(refund.text.trim()) ?? 0;
    if (qty <= 0 || refundRs < 0) {
      _notify('Settlement values invalid');
      return;
    }
    try {
      await _repo.settleDeposit(
        depositId: dep['id'].toString(),
        returnedQuantity: qty,
        refundAmountCents: (refundRs * 100).round(),
        notes: notes.text,
      );
      _notify('Deposit settled');
      await _refreshAll();
    } on HardwareOpsException catch (e) {
      _notify('Deposit settle failed: ${e.message}');
    }
  }

  Future<bool?> _showFormDialog({
    required String title,
    required List<Widget> fields,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: fields),
        ),
        actions: _dialogActions(),
      ),
    );
  }

  List<Widget> _dialogActions() => [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: const Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pop(context, true),
      child: const Text('Save'),
    ),
  ];

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    // Numeric-field guard (bugfix.md 2.21): reject non-numeric characters at
    // the keystroke level so invalid input cannot silently parse to 0. Applied
    // automatically to numeric fields; callers may override with their own
    // formatters.
    final formatters =
        inputFormatters ??
        (keyboardType == TextInputType.number ? _numericInputFormatters : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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

  Future<void> _setDepositFilter(String? value) async {
    setState(() => _depositStatusFilter = value);
    await _persistDepositFilter(value);
  }

  Future<void> _loadPersistedDepositFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_scopedDepositFilterKey());
    if (!mounted) return;
    if (persisted == null || persisted.isEmpty) return;
    setState(() => _depositStatusFilter = persisted);
  }

  Future<void> _persistDepositFilter(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_scopedDepositFilterKey());
      return;
    }
    await prefs.setString(_scopedDepositFilterKey(), value);
  }

  Future<void> _loadPersistedTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_scopedTabIndexKey());
    if (!mounted || idx == null) return;
    final safe = idx.clamp(0, 2);
    if (_tabController.index != safe) {
      _tabController.animateTo(safe);
    }
  }

  Future<void> _persistTabIndex(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedTabIndexKey(), idx.clamp(0, 2));
  }

  String _scopedDepositFilterKey() => '${_depositFilterPrefKey}_$_ownerScope';
  String _scopedTabIndexKey() => '${_tabIndexPrefKey}_$_ownerScope';

  String _hardwareBadgeLabel() {
    final tab = _tabController.index;
    if (tab == 0) return 'Projects';
    if (tab == 1) return 'Indents';
    if (_depositStatusFilter == 'open') return 'Deposits · Open';
    if (_depositStatusFilter == 'closed') return 'Deposits · Closed';
    return 'Deposits · All';
  }

  Future<void> _resetFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedDepositFilterKey());
    await prefs.remove(_scopedTabIndexKey());
    if (!mounted) return;
    setState(() => _depositStatusFilter = null);
    _tabController.animateTo(0);
    await _refreshAll();
    _notify('Hardware filters reset');
  }
}
