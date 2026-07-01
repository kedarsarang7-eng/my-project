import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';

class DeadStockTab extends ConsumerStatefulWidget {
  const DeadStockTab({super.key});

  @override
  ConsumerState<DeadStockTab> createState() => _DeadStockTabState();
}

class _DeadStockTabState extends ConsumerState<DeadStockTab> {
  int _selectedDays = 90; // Default cutoff
  bool _isLoading = true;
  List<Product> _deadStockItems = [];
  double _blockedCapital = 0;

  @override
  void initState() {
    super.initState();
    _fetchDeadStock();
  }

  Future<void> _fetchDeadStock() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId != null) {
        final result = await sl<ProductsRepository>().getDeadStock(
          userId: userId,
          daysUnsold: _selectedDays,
        );
        if (result.isSuccess) {
          final items = result.data ?? [];
          setState(() {
            _deadStockItems = items;
            _blockedCapital = items.fold(
              0,
              (sum, p) =>
                  sum +
                  (p.costPrice > 0 ? p.costPrice : p.sellingPrice * 0.7) *
                      p.stockQuantity,
            );
            // Fallback to 70% of selling price if cost price not set
          });
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeStateProvider).isDark;

    return Column(
      children: [
        // 1. Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Row(
            children: [
              const Text(
                'Unsold for:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [30, 60, 90].map((days) {
                  final isSelected = _selectedDays == days;
                  return ChoiceChip(
                    label: Text('$days Days'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDays = days);
                        _fetchDeadStock();
                      }
                    },
                    selectedColor: FuturisticColors.warning.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? FuturisticColors.warning
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // 2. Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF331D22), const Color(0xFF1E1E1E)]
                  : [const Color(0xFFFFF0F0), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: FuturisticColors.warning.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: FuturisticColors.warning.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blocked Capital',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_blockedCapital.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: FuturisticColors.warning,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FuturisticColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.money_off,
                  color: FuturisticColors.warning,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        // 3. List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deadStockItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: FuturisticColors.success.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Great job! No dead stock found.',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _deadStockItems.length,
                  itemBuilder: (context, index) {
                    final product = _deadStockItems[index];
                    return _buildDeadStockCard(product, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDeadStockCard(Product p, bool isDark) {
    // Suggestion logic
    String suggestion = '';
    Color suggestionColor = Colors.orange;

    if (_selectedDays >= 90) {
      suggestion = 'Clearance Sale: Flat 25% Off';
      suggestionColor = FuturisticColors.error;
    } else if (_selectedDays >= 60) {
      suggestion = 'Discount: 15% Off or Bundle';
      suggestionColor = Colors.orange;
    } else {
      suggestion = 'Monitor Closely / Bundle';
      suggestionColor = Colors.blue;
    }

    final blockedValue =
        (p.costPrice > 0 ? p.costPrice : p.sellingPrice * 0.7) *
        p.stockQuantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              p.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Stock: ${p.stockQuantity} ${p.unit} | Blocked: ₹${blockedValue.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_selectedDays+ Days',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Action Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: suggestionColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: suggestionColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: suggestionColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: suggestionColor.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
