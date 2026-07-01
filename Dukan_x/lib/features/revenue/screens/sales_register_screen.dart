import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/services/report_export_service.dart';
import '../../../core/database/app_database.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
// import '../../../models/bill.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Sales Register Screen
///
/// Filterable list of all sales invoices with:
/// - Date range filter
/// - Customer filter
/// - Status filter
/// - Search
/// - Export options
class SalesRegisterScreen extends ConsumerStatefulWidget {
  const SalesRegisterScreen({super.key});

  @override
  ConsumerState<SalesRegisterScreen> createState() =>
      _SalesRegisterScreenState();
}

class _SalesRegisterScreenState extends ConsumerState<SalesRegisterScreen> {
  bool _loading = true;
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];

  // Filters
  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  // Sorting
  String _sortBy = 'date';
  bool _sortAscending = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final billsRepo = sl<BillsRepository>();
      final result = await billsRepo.getAll(userId: userId);
      _allBills = result.data ?? [];
      _applyFilters();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    List<Bill> filtered = List.from(_allBills);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((b) {
        final query = _searchQuery.toLowerCase();
        return (b.invoiceNumber.toLowerCase().contains(query)) ||
            (b.customerName.toLowerCase().contains(query));
      }).toList();
    }

    // Status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((b) {
        switch (_statusFilter) {
          case 'Paid':
            return b.paidAmount >= b.grandTotal;
          case 'Partial':
            return b.paidAmount > 0 && b.paidAmount < b.grandTotal;
          case 'Unpaid':
            return b.paidAmount == 0;
          default:
            return true;
        }
      }).toList();
    }

    // Date range filter
    if (_startDate != null) {
      filtered = filtered.where((b) => b.date.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      filtered = filtered.where((b) => b.date.isBefore(endOfDay)).toList();
    }

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'date':
          comparison = a.date.compareTo(b.date);
          break;
        case 'amount':
          comparison = a.grandTotal.compareTo(b.grandTotal);
          break;
        case 'customer':
          comparison = (a.customerName).compareTo(b.customerName);
          break;
        default:
          comparison = a.date.compareTo(b.date);
      }
      return _sortAscending ? comparison : -comparison;
    });

    _filteredBills = filtered;
  }

  Future<void> _exportData() async {
    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) return;

    setState(() => _loading = true);

    try {
      final exportService = ReportExportService(database: sl<AppDatabase>());

      // Default to "All Time" if no date selected
      final fromDate = _startDate ?? DateTime(2020);
      final toDate = _endDate ?? DateTime.now();

      final result = await exportService.exportSalesRegister(
        userId: userId,
        fromDate: fromDate,
        toDate: toDate,
        format: ExportFormat.csv,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Exported ${result.recordCount} invoices to ${result.filePath}',
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${result.error}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Sales Register',
      subtitle: '${_filteredBills.length} of ${_allBills.length} invoices',
      showScrollbar: false,
      actions: [
        DesktopActionButton(
          icon: Icons.download,
          label: 'Export',
          onPressed: _exportData,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 8),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          _buildFilters(isDark),
          _buildSummaryRow(isDark),
          Expanded(child: _buildTable(isDark)),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      // On narrow screens the intrinsic-width dropdown/date controls no
      // longer fit beside the search field, so we stack the search field on
      // its own row and let the controls reflow with Wrap. Desktop/tablet
      // keep the original single-row layout unchanged.
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(isDark),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _buildFilterControls(isDark),
                ),
              ],
            )
          : Row(
              children: [
                // Search
                Expanded(flex: 2, child: _buildSearchField(isDark)),
                const SizedBox(width: 16),
                ..._buildFilterControls(isDark),
              ],
            ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applyFilters();
        });
      },
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'Search by invoice # or customer...',
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: isDark ? Colors.white38 : Colors.grey,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  /// Builds the status filter, date-range picker and (conditional) clear
  /// control. Shared by the desktop Row and the mobile Wrap so behaviour
  /// stays consistent across layouts.
  List<Widget> _buildFilterControls(bool isDark) {
    return [
      // Status Filter
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _statusFilter,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            items: ['All', 'Paid', 'Partial', 'Unpaid']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _statusFilter = value;
                  _applyFilters();
                });
              }
            },
          ),
        ),
      ),

      // Date Range
      OutlinedButton.icon(
        onPressed: () async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _startDate != null && _endDate != null
                ? DateTimeRange(start: _startDate!, end: _endDate!)
                : null,
          );
          if (range != null) {
            setState(() {
              _startDate = range.start;
              _endDate = range.end;
              _applyFilters();
            });
          }
        },
        icon: const Icon(Icons.calendar_today, size: 18),
        label: Text(
          _startDate != null && _endDate != null
              ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
              : 'Date Range',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
        ),
      ),

      if (_startDate != null)
        IconButton(
          onPressed: () {
            setState(() {
              _startDate = null;
              _endDate = null;
              _applyFilters();
            });
          },
          icon: const Icon(Icons.clear, size: 18),
          color: isDark ? Colors.white54 : Colors.grey,
        ),
    ];
  }

  Widget _buildSummaryRow(bool isDark) {
    final totalSales = _filteredBills.fold(0.0, (sum, b) => sum + b.grandTotal);
    final totalCollected = _filteredBills.fold(
      0.0,
      (sum, b) => sum + b.paidAmount,
    );
    final totalDue = totalSales - totalCollected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      child: Row(
        children: [
          // Each chip is wrapped in Flexible so the three share the row width
          // evenly and shrink (rather than overflow) on narrow screens.
          Flexible(
            child: _buildSummaryChip(
              'Total Sales',
              '₹${totalSales.toStringAsFixed(0)}',
              const Color(0xFF10B981),
              isDark,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: _buildSummaryChip(
              'Collected',
              '₹${totalCollected.toStringAsFixed(0)}',
              const Color(0xFF06B6D4),
              isDark,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: _buildSummaryChip(
              'Due',
              '₹${totalDue.toStringAsFixed(0)}',
              const Color(0xFFEF4444),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          // The value can be a large amount; constrain it so a Flexible chip
          // on a narrow screen ellipsises instead of overflowing its row.
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredBills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No invoices found',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(
          isDark ? const Color(0xFF1E293B) : Colors.grey[200],
        ),
        dataRowColor: MaterialStateProperty.all(
          isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
        columns: [
          DataColumn(
            label: _buildSortableHeader('Date', 'date', isDark),
            onSort: (_, _) => _toggleSort('date'),
          ),
          DataColumn(
            label: _buildSortableHeader('Invoice #', 'invoice', isDark),
          ),
          DataColumn(
            label: _buildSortableHeader('Customer', 'customer', isDark),
            onSort: (_, _) => _toggleSort('customer'),
          ),
          DataColumn(
            label: _buildSortableHeader('Amount', 'amount', isDark),
            onSort: (_, _) => _toggleSort('amount'),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Paid',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          DataColumn(
            label: Text(
              'Due',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
        rows: _filteredBills
            .map((bill) => _buildDataRow(bill, isDark))
            .toList(),
      ),
    );
  }

  Widget _buildSortableHeader(String text, String sortKey, bool isDark) {
    final isActive = _sortBy == sortKey;
    return InkWell(
      onTap: () => _toggleSort(sortKey),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? const Color(0xFF06B6D4)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          if (isActive)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: const Color(0xFF06B6D4),
            ),
        ],
      ),
    );
  }

  void _toggleSort(String sortKey) {
    setState(() {
      if (_sortBy == sortKey) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortKey;
        _sortAscending = false;
      }
      _applyFilters();
    });
  }

  DataRow _buildDataRow(Bill bill, bool isDark) {
    final isPaid = bill.paidAmount >= bill.grandTotal;
    final isPartial = bill.paidAmount > 0 && bill.paidAmount < bill.grandTotal;
    final due = bill.grandTotal - bill.paidAmount;

    return DataRow(
      cells: [
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy').format(bill.date),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        DataCell(
          Text(
            bill.invoiceNumber,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        DataCell(
          Text(
            bill.customerName.isEmpty ? 'Walk-in' : bill.customerName,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
        ),
        DataCell(
          Text(
            '₹${bill.grandTotal.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        DataCell(
          Text(
            '₹${bill.paidAmount.toStringAsFixed(0)}',
            style: const TextStyle(color: Color(0xFF10B981)),
          ),
        ),
        DataCell(
          Text(
            '₹${due.toStringAsFixed(0)}',
            style: TextStyle(
              color: due > 0
                  ? const Color(0xFFEF4444)
                  : (isDark ? Colors.white38 : Colors.grey),
            ),
          ),
        ),
        DataCell(_buildStatusBadge(isPaid, isPartial)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 18),
                color: isDark ? Colors.white54 : Colors.grey,
                onPressed: () {
                  // View bill details
                },
              ),
              IconButton(
                icon: const Icon(Icons.print, size: 18),
                color: isDark ? Colors.white54 : Colors.grey,
                onPressed: () {
                  // Print bill
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isPaid, bool isPartial) {
    String label;
    Color color;

    if (isPaid) {
      label = 'Paid';
      color = const Color(0xFF10B981);
    } else if (isPartial) {
      label = 'Partial';
      color = const Color(0xFFF59E0B);
    } else {
      label = 'Unpaid';
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
