import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../models/payment_history.dart';
import '../core/di/service_locator.dart';
import '../core/session/session_manager.dart';
import '../core/repository/customers_repository.dart';

class BlacklistManagementScreen extends StatefulWidget {
  const BlacklistManagementScreen({super.key});

  @override
  State<BlacklistManagementScreen> createState() =>
      _BlacklistManagementScreenState();
}

class _BlacklistManagementScreenState extends State<BlacklistManagementScreen> {
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;
  List<BlacklistedCustomer> _blacklistedCustomers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      if (ownerId.isEmpty) return;

      // Use repository to get customers with dues (potential blacklist)
      final result = await sl<CustomersRepository>().getCustomersWithDues(
        userId: ownerId,
      );

      if (!result.isSuccess || !mounted) return;

      // Map to BlacklistedCustomer - customers with high dues
      final customers = result.data!;
      final blacklist = customers
          .where((c) => c.totalDues > 5000) // Threshold for blacklist
          .map(
            (c) => BlacklistedCustomer(
              customerId: c.id,
              customerName: c.name,
              blacklistDate: c.updatedAt,
              duesAmount: c.totalDues,
              reason: 'Outstanding dues',
            ),
          )
          .toList();

      setState(() => _blacklistedCustomers = blacklist);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _selectedFromDate = picked;
        } else {
          _selectedToDate = picked;
        }
      });
    }
  }

  Future<void> _filterByDateRange() async {
    if (_selectedFromDate == null || _selectedToDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select both dates')));
      return;
    }

    // Filter already loaded list by date
    final filtered = _blacklistedCustomers
        .where(
          (c) =>
              c.blacklistDate.isAfter(
                _selectedFromDate!.subtract(const Duration(days: 1)),
              ) &&
              c.blacklistDate.isBefore(
                _selectedToDate!.add(const Duration(days: 1)),
              ),
        )
        .toList();

    setState(() => _blacklistedCustomers = filtered);
  }

  Future<void> _removeFromBlacklist(String customerId) async {
    // Just remove from local list (UI-only operation)
    // Actual blacklist management would need a proper blacklist repository
    setState(() {
      _blacklistedCustomers.removeWhere((c) => c.customerId == customerId);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from blacklist')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Blacklist Management'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: ResponsiveContainer(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Filter
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter by Date Range',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectDate(context, true),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    _selectedFromDate == null
                                        ? 'From Date'
                                        : '${_selectedFromDate!.day}/${_selectedFromDate!.month}/${_selectedFromDate!.year}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectDate(context, false),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    _selectedToDate == null
                                        ? 'To Date'
                                        : '${_selectedToDate!.day}/${_selectedToDate!.month}/${_selectedToDate!.year}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _filterByDateRange,
                              icon: const Icon(Icons.search),
                              label: const Text('Filter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Blacklist Stats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              '⛔ Total Blacklisted',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _blacklistedCustomers.length.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              '💰 Total Dues',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_blacklistedCustomers.fold(0.0, (sum, c) => sum + c.duesAmount).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Blacklist Listf
                  const Text(
                    'Blacklisted Customers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _blacklistedCustomers.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text(
                            'No blacklisted customers',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _blacklistedCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _blacklistedCustomers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: const Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                ),
                                title: Text(customer.customerName),
                                subtitle: Text(
                                  'Dues: ₹${customer.duesAmount.toStringAsFixed(2)}',
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow(
                                          'Blacklist Date',
                                          customer.blacklistDate
                                              .toString()
                                              .split(' ')[0],
                                        ),
                                        _buildInfoRow(
                                          'From Date',
                                          customer.fromDate?.toString().split(
                                                ' ',
                                              )[0] ??
                                              'N/A',
                                        ),
                                        _buildInfoRow(
                                          'To Date',
                                          customer.toDate?.toString().split(
                                                ' ',
                                              )[0] ??
                                              'N/A',
                                        ),
                                        _buildInfoRow(
                                          'Reason',
                                          customer.reason,
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _removeFromBlacklist(
                                                  customer.customerId,
                                                ),
                                            icon: const Icon(
                                              Icons.check_circle,
                                            ),
                                            label: const Text(
                                              'Remove from Blacklist',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
