// Hallmark Inventory Screen - HUID Compliance
// Track Hallmark Unique IDs for BIS compliance

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HallmarkInventoryScreen extends StatefulWidget {
  const HallmarkInventoryScreen({super.key});

  @override
  State<HallmarkInventoryScreen> createState() =>
      _HallmarkInventoryScreenState();
}

class _HallmarkInventoryScreenState extends State<HallmarkInventoryScreen> {
  final JewelleryRepositoryOffline _repository = JewelleryRepositoryOffline(
    sl(),
    sl<SessionManager>(),
  );

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<HallmarkRegisterEntry> _entries = [];
  List<HallmarkRegisterEntry> _filteredEntries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _selectedPurity;
  String? _selectedStatus;

  // Requirement 16.1/16.2: Explicit pagination — never load the whole Hive box.
  static const int _pageSize = 50;
  int _currentOffset = 0;

  final List<String> _purityOptions = ['999', '916', '750', '585'];
  final List<String> _statusOptions = ['ALL', 'ACTIVE', 'SOLD'];

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll listener for infinite-scroll pagination (Requirement 16.2).
  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreEntries();
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      await _repository.initialize();

      final status = _selectedStatus == 'ALL' ? null : _selectedStatus;
      PurityStandard? purity;
      if (_selectedPurity != null) {
        purity = PurityStandard.values.firstWhere(
          (p) => p.code == _selectedPurity,
          orElse: () => PurityStandard.p916,
        );
      }

      // Requirement 16.1/16.2: Pass explicit limit/offset.
      final entries = await _repository.getHallmarkRegister(
        status: status,
        purityStandard: purity,
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _entries = entries;
          _filteredEntries = entries;
          _currentOffset = entries.length;
          _hasMore = entries.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load hallmark entries: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Load the next page of hallmark entries (Requirement 16.2).
  Future<void> _loadMoreEntries() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final status = _selectedStatus == 'ALL' ? null : _selectedStatus;
      PurityStandard? purity;
      if (_selectedPurity != null) {
        purity = PurityStandard.values.firstWhere(
          (p) => p.code == _selectedPurity,
          orElse: () => PurityStandard.p916,
        );
      }

      final moreEntries = await _repository.getHallmarkRegister(
        status: status,
        purityStandard: purity,
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          _entries.addAll(moreEntries);
          _filteredEntries = _entries;
          _currentOffset += moreEntries.length;
          _hasMore = moreEntries.length >= _pageSize;
        });
        // Re-apply local search filter if active
        if (_searchController.text.isNotEmpty) {
          _onSearchChanged();
        }
      }
    } catch (e) {
      // Silently fail on load-more; user can scroll again to retry
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEntries = _entries.where((entry) {
        return entry.huid.toLowerCase().contains(query) ||
            entry.productName.toLowerCase().contains(query) ||
            (entry.articleType?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _registerNewHallmark() async {
    final result = await showDialog<HallmarkRegisterEntry>(
      context: context,
      builder: (context) => const RegisterHallmarkDialog(),
    );

    if (result != null) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hallmark registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : isDesktop
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registerNewHallmark,
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Register HUID',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadEntries, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildAppBar(),
        _buildFilterBar(),
        Expanded(child: _buildDataTable()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(child: _buildAppBar()),
        SliverToBoxAdapter(child: _buildFilterBar()),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= _filteredEntries.length) return null;
            return _buildMobileCard(_filteredEntries[index]);
          }, childCount: _filteredEntries.length),
        ),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37),
                  const Color(0xFFD4AF37).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hallmark Register',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredEntries.length} HUID entries',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // BIS Compliance badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'BIS Compliant',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: Column(
        children: [
          // Search field — always full width
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by HUID or product name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filters row — wraps on mobile
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Purity filter
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedPurity,
                      hint: const Text('Purity'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Purity'),
                        ),
                        ..._purityOptions.map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text('$p (${_getPurityName(p)})'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPurity = value);
                        _loadEntries();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status filter
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedStatus ?? 'ALL',
                      items: _statusOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedStatus = value);
                        _loadEntries();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadEntries,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPurityName(String code) {
    switch (code) {
      case '999':
        return '24K';
      case '916':
        return '22K';
      case '750':
        return '18K';
      case '585':
        return '14K';
      default:
        return '';
    }
  }

  Widget _buildDataTable() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable2(
          columnSpacing: 16,
          horizontalMargin: 16,
          minWidth: 900,
          columns: const [
            DataColumn2(label: Text('HUID'), size: ColumnSize.S),
            DataColumn2(label: Text('Product'), size: ColumnSize.L),
            DataColumn2(label: Text('Purity'), size: ColumnSize.S),
            DataColumn2(label: Text('Weight'), size: ColumnSize.S),
            DataColumn2(label: Text('Date'), size: ColumnSize.S),
            DataColumn2(label: Text('Status'), size: ColumnSize.S),
            DataColumn2(label: Text('Actions'), size: ColumnSize.S),
          ],
          rows: _filteredEntries.map((entry) => _buildDataRow(entry)).toList(),
          empty: _buildEmptyState(),
        ),
      ),
    );
  }

  DataRow2 _buildDataRow(HallmarkRegisterEntry entry) {
    final isSold = entry.status == 'SOLD';
    final purityColor = _getPurityColor(entry.purityStandard);

    return DataRow2(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.huid,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.productName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (entry.articleType != null)
                Text(
                  entry.articleType!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: purityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: purityColor.withOpacity(0.3)),
            ),
            child: Text(
              entry.purityStandard.code,
              style: TextStyle(fontWeight: FontWeight.w600, color: purityColor),
            ),
          ),
        ),
        DataCell(Text('${entry.weightGrams.toStringAsFixed(2)} g')),
        DataCell(
          Text(
            DateFormat('MMM d, yyyy').format(entry.hallmarkDate),
            style: TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSold
                  ? Colors.green.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              entry.status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSold ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ),
        DataCell(
          EntityActionPanel.standard(
            onView: () => _viewEntryDetails(entry),
            onEdit: () => _editEntry(entry),
            onDelete: () => _deleteEntry(entry),
            canEdit: entry.status == 'ACTIVE',
            canDelete: entry.status == 'ACTIVE',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(HallmarkRegisterEntry entry) {
    final isSold = entry.status == 'SOLD';
    final purityColor = _getPurityColor(entry.purityStandard);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: purityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: purityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    entry.purityStandard.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: purityColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSold
                        ? Colors.green.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSold ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (entry.articleType != null)
              Text(
                entry.articleType!,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('HUID', entry.huid),
                const SizedBox(width: 12),
                _buildInfoChip(
                  'Weight',
                  '${entry.weightGrams.toStringAsFixed(2)} g',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Hallmarked: ${DateFormat('MMM d, yyyy').format(entry.hallmarkDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isSold && entry.soldDate != null)
              Text(
                'Sold: ${DateFormat('MMM d, yyyy').format(entry.soldDate!)}',
                style: TextStyle(fontSize: 12, color: Colors.green[700]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPurityColor(PurityStandard purity) {
    switch (purity) {
      case PurityStandard.p999:
        return const Color(0xFFFFD700); // Gold
      case PurityStandard.p916:
        return const Color(0xFFFFE55C); // Light gold
      case PurityStandard.p750:
        return const Color(0xFFE6C200); // Darker gold
      case PurityStandard.p585:
        return const Color(0xFFB8860B); // Dark gold
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hallmark entries',
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
              ),
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register your first HUID',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _viewEntryDetails(HallmarkRegisterEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('HUID: ${entry.huid}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Product', entry.productName),
            _buildDetailRow('Article Type', entry.articleType ?? 'N/A'),
            _buildDetailRow('Purity', entry.purityStandard.displayName),
            _buildDetailRow('Weight', '${entry.weightGrams} g'),
            _buildDetailRow('Status', entry.status),
            _buildDetailRow(
              'Hallmark Date',
              DateFormat('MMM d, yyyy').format(entry.hallmarkDate),
            ),
            if (entry.registrationNumber != null)
              _buildDetailRow('BIS Reg. No.', entry.registrationNumber!),
            if (entry.saleInvoiceId != null)
              _buildDetailRow('Invoice', entry.saleInvoiceId!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _editEntry(HallmarkRegisterEntry entry) {
    // Implementation for editing entry
  }

  void _deleteEntry(HallmarkRegisterEntry entry) {
    // Implementation for deleting entry
  }
}

// Dialog for registering new hallmark
class RegisterHallmarkDialog extends StatefulWidget {
  const RegisterHallmarkDialog({super.key});

  @override
  State<RegisterHallmarkDialog> createState() => _RegisterHallmarkDialogState();
}

class _RegisterHallmarkDialogState extends State<RegisterHallmarkDialog> {
  final _huidController = TextEditingController();
  final _productNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _regNumberController = TextEditingController();

  PurityStandard _selectedPurity = PurityStandard.p916;
  String? _articleType;

  final List<String> _articleTypes = [
    'Ring',
    'Chain',
    'Necklace',
    'Earring',
    'Bracelet',
    'Bangle',
    'Pendant',
    'Other',
  ];

  @override
  void dispose() {
    _huidController.dispose();
    _productNameController.dispose();
    _weightController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final huid = _huidController.text.trim();
    final productName = _productNameController.text.trim();
    final weight = double.tryParse(_weightController.text);

    if (huid.isEmpty || huid.length != 6) {
      _showError('HUID must be 6 characters');
      return;
    }

    if (productName.isEmpty) {
      _showError('Product name is required');
      return;
    }

    if (weight == null || weight <= 0) {
      _showError('Please enter a valid weight');
      return;
    }

    final repository = JewelleryRepositoryOffline(sl(), sl<SessionManager>());
    await repository.initialize();

    final entry = await repository.registerHallmark(
      productId: 'TEMP_${DateTime.now().millisecondsSinceEpoch}',
      productName: productName,
      huid: huid,
      purityStandard: _selectedPurity,
      weightGrams: weight,
      articleType: _articleType,
      hallmarkDate: DateTime.now(),
      registrationNumber: _regNumberController.text.isNotEmpty
          ? _regNumberController.text
          : null,
    );

    Navigator.pop(context, entry);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 500,
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFD4AF37)),
                const SizedBox(width: 12),
                Text(
                  'Register New HUID',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // HUID
            TextField(
              controller: _huidController,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'HUID *',
                hintText: '6-digit Hallmark ID',
                counterText: '',
                prefixIcon: const Icon(Icons.confirmation_number),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Name
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g., 22K Gold Ring',
                prefixIcon: const Icon(Icons.diamond),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Article Type
            DropdownButtonFormField<String>(
              value: _articleType,
              decoration: InputDecoration(
                labelText: 'Article Type',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select Type')),
                ..._articleTypes.map(
                  (type) => DropdownMenuItem(value: type, child: Text(type)),
                ),
              ],
              onChanged: (value) {
                setState(() => _articleType = value);
              },
            ),
            const SizedBox(height: 16),

            // Purity
            DropdownButtonFormField<PurityStandard>(
              value: _selectedPurity,
              decoration: InputDecoration(
                labelText: 'Purity Standard *',
                prefixIcon: const Icon(Icons.star),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: PurityStandard.values
                  .map(
                    (p) =>
                        DropdownMenuItem(value: p, child: Text(p.displayName)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPurity = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Weight
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (grams) *',
                prefixIcon: const Icon(Icons.scale),
                suffixText: 'g',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // BIS Registration Number
            TextField(
              controller: _regNumberController,
              decoration: InputDecoration(
                labelText: 'BIS Registration Number',
                hintText: 'Optional',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('REGISTER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
