import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ProductPerformanceScreen extends ConsumerStatefulWidget {
  const ProductPerformanceScreen({super.key});

  @override
  ConsumerState<ProductPerformanceScreen> createState() =>
      _ProductPerformanceScreenState();
}

class _ProductPerformanceScreenState
    extends ConsumerState<ProductPerformanceScreen> {
  bool _loading = true;
  String _filter = 'top_selling'; // top_selling, low_moving, high_margin
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final userId = ref.read(authStateProvider).userId ?? '';
      if (userId.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final result = await sl<ProductsRepository>().getSalesPerformance(userId);

      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        // Filter is applied in UI or we can select list here
        // The repository returns: 'top_selling', 'low_moving', 'high_margin'

        List<Map<String, dynamic>> rawList = [];
        if (_filter == 'top_selling') {
          rawList = List<Map<String, dynamic>>.from(data['top_selling'] ?? []);
        } else if (_filter == 'low_moving') {
          rawList = List<Map<String, dynamic>>.from(data['low_moving'] ?? []);
        } else if (_filter == 'high_margin') {
          rawList = List<Map<String, dynamic>>.from(data['high_margin'] ?? []);
        }

        if (mounted) {
          setState(() {
            _products = rawList;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading performance data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Product Performance',
      subtitle: 'Analyze top movers, slow stock, and profit margins',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: () {
            _loadData();
          },
        ),
      ],
      child: Column(
        children: [
          // Filter Bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              children: [
                _buildDesktopFilterChip('Top Selling', 'top_selling'),
                _buildDesktopFilterChip('Low Moving', 'low_moving'),
                _buildDesktopFilterChip('High Margin', 'high_margin'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : EnterpriseTable<Map<String, dynamic>>(
                    data: _products,
                    columns: [
                      EnterpriseTableColumn(
                        title: 'Product Name',
                        valueBuilder: (p) => p['name'],
                        widgetBuilder: (p) => Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: FuturisticColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      EnterpriseTableColumn(
                        title: 'Category',
                        valueBuilder: (p) => p['category'],
                      ),
                      EnterpriseTableColumn(
                        title: 'Sold Qty',
                        valueBuilder: (p) => p['sold_qty'],
                        isNumeric: true,
                      ),
                      EnterpriseTableColumn(
                        title: 'Revenue',
                        valueBuilder: (p) => p['revenue'],
                        isNumeric: true,
                        widgetBuilder: (p) => Text(
                          '₹${(p['revenue'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: FuturisticColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      EnterpriseTableColumn(
                        title: 'Margin %',
                        valueBuilder: (p) => p['margin'],
                        isNumeric: true,
                        widgetBuilder: (p) {
                          final margin = (p['margin'] as double? ?? 0);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: margin > 15
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$margin%',
                              style: TextStyle(
                                color: margin > 15 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _filter = value);
          _loadData();
        }
      },
      selectedColor: FuturisticColors.accent1,
      backgroundColor: Colors.white.withOpacity(0.05),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
