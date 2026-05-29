import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/license_provider.dart';
import '../../../providers/staff_provider.dart';

/// Staff Transactions Screen
/// 
/// Mobile-optimized transaction history for staff members.
/// Shows personal transactions with filtering and search.
class StaffTransactionsScreen extends ConsumerStatefulWidget {
  const StaffTransactionsScreen({super.key});

  @override
  ConsumerState<StaffTransactionsScreen> createState() => _StaffTransactionsScreenState();
}

class _StaffTransactionsScreenState extends ConsumerState<StaffTransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Petrol', 'Diesel', 'UPI', 'Cash'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final staffId = ref.read(licenseProvider).profile?.userId;
      if (staffId != null) {
        ref.read(staffDetailsProvider.notifier).loadTransactions(staffId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(currentStaffTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go('/staff-mobile'),
        ),
        title: const Text(
          'My Transactions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterBottomSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),
          
          // Filter Chips
          _buildFilterChips(),
          
          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) => _buildTransactionsList(transactions),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => _buildError(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E3A5F),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search transactions...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.6)),
            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha:0.6)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.white.withValues(alpha:0.6)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> transactions) {
    // Filter transactions
    var filtered = transactions.where((t) {
      // Text filter
      final searchText = _searchController.text.toLowerCase();
      if (searchText.isNotEmpty) {
        final matches = t['id'].toString().toLowerCase().contains(searchText) ||
            t['amount'].toString().contains(searchText) ||
            t['fuelType'].toString().toLowerCase().contains(searchText);
        if (!matches) return false;
      }
      
      // Category filter
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Petrol' || _selectedFilter == 'Diesel') {
        return t['fuelType'].toString() == _selectedFilter;
      }
      if (_selectedFilter == 'UPI' || _selectedFilter == 'Cash') {
        return t['paymentMethod'].toString() == _selectedFilter.toLowerCase();
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    // Group by date
    final grouped = _groupByDate(filtered);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final dayTransactions = grouped[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDateHeader(date),
                      style: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dayTransactions.length} transactions',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Transaction Cards
            ...dayTransactions.map((t) => _buildTransactionCard(t)),
          ],
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> transactions) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final t in transactions) {
      final date = t['createdAt'].toString().split('T')[0];
      grouped.putIfAbsent(date, () => []).add(t);
    }
    
    // Sort by date descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  }

  String _formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Yesterday';
    }
    
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final timeFormatter = DateFormat('h:mm a');
    
    final fuelType = transaction['fuelType'] as String? ?? 'Petrol';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final liters = (transaction['liters'] as num?)?.toDouble() ?? 0;
    final paymentMethod = transaction['paymentMethod'] as String? ?? 'UPI';
    final status = transaction['status'] as String? ?? 'completed';
    final createdAt = transaction['createdAt'] as String? ?? '';
    
    final fuelColor = fuelType == 'Petrol' ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fuel Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fuelColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.local_gas_station,
                color: fuelColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$fuelType Sale',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      currencyFormatter.format(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${liters.toStringAsFixed(1)} L • ${paymentMethod.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        timeFormatter.format(DateTime.parse(createdAt)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? const Color(0xFF10B981).withValues(alpha:0.1)
                        : const Color(0xFFF59E0B).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start processing payments to see your\ntransaction history here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/staff-mobile/quick-pay'),
            icon: const Icon(Icons.add),
            label: const Text('Create New Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load transactions',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final staffId = ref.read(licenseProvider).profile?.userId;
              if (staffId != null) {
                ref.read(staffDetailsProvider.notifier).loadTransactions(staffId);
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ..._filters.map((filter) => ListTile(
                  leading: Icon(
                    _getFilterIcon(filter),
                    color: _selectedFilter == filter 
                        ? const Color(0xFF1E3A5F)
                        : Colors.grey,
                  ),
                  title: Text(filter),
                  trailing: _selectedFilter == filter
                      ? const Icon(Icons.check_circle, color: Color(0xFF1E3A5F))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Petrol':
        return Icons.local_gas_station;
      case 'Diesel':
        return Icons.local_gas_station;
      case 'UPI':
        return Icons.qr_code;
      case 'Cash':
        return Icons.money;
      default:
        return Icons.filter_list;
    }
  }
}

// Provider for current staff transactions
final currentStaffTransactionsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  // This would fetch the current user's transactions
  return const AsyncValue.data([]);
});
