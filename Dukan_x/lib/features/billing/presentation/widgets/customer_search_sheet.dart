// ============================================================================
// CUSTOMER SEARCH SHEET - FUTURISTIC UI
// ============================================================================
// Search and select customers from local database
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../features/ai_assistant/services/customer_recommendation_service.dart';

class CustomerSearchSheet extends StatefulWidget {
  final Function(Customer) onCustomerSelected;

  const CustomerSearchSheet({super.key, required this.onCustomerSelected});

  @override
  State<CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<CustomerSearchSheet> {
  final _searchController = TextEditingController();
  final _customerRepo = sl<CustomersRepository>();
  final _recService = sl<CustomerRecommendationService>(); // AI Service
  final _session = sl<SessionManager>();

  List<Customer> _allCustomers = [];
  List<Customer> _filtered = [];
  List<Customer> _recommended = []; // AI Predictions
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filter);
  }

  Future<void> _loadData() async {
    final userId = _session.ownerId;
    if (userId == null) return;

    // Parallel Fetch: All Customers + AI Recommendations
    final results = await Future.wait([
      _customerRepo.getAll(userId: userId),
      _recService.getRecommendedCustomers(userId: userId, limit: 5),
    ]);

    final allCustResult = results[0] as RepositoryResult<List<Customer>>;
    final recList = results[1] as List<Customer>;

    if (mounted) {
      setState(() {
        _allCustomers = allCustResult.data ?? [];
        _filtered = _allCustomers;
        _recommended = recList;
        _isLoading = false;
      });
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allCustomers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            (c.phone?.contains(q) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.black12 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // AI Recommendations Section
          if (!_isLoading &&
              _recommended.isNotEmpty &&
              _searchController.text.isEmpty)
            _buildRecommendationSection(isDark),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final c = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name[0])),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(c.phone ?? ''),
                        onTap: () {
                          widget.onCustomerSelected(c);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.purpleAccent.shade100,
              ),
              const SizedBox(width: 8),
              Text(
                'Predicted for You',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.purpleAccent.shade100 : Colors.purple,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recommended.length,
            itemBuilder: (context, index) {
              final c = _recommended[index];
              return Container(
                width: 70,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        widget.onCustomerSelected(c);
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: isDark
                            ? Colors.purple.withOpacity(0.2)
                            : Colors.purple.shade50,
                        child: Text(
                          c.name[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.purple,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
}
