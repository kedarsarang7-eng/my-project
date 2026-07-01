import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';
import '../../../../../../utils/currency_formatter.dart';

class PharmacyTopProductsTable extends ConsumerWidget {
  const PharmacyTopProductsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(pharmacyTopProductsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: productsAsync.when(
              data: (data) => _buildTable(context, data),
              loading: () => _buildLoadingTable(),
              error: (_, _) => _buildErrorTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FuturisticColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.trending_up_rounded,
            color: FuturisticColors.success,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Selling Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Top 5 products by revenue',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, TopSellingProductsData data) {
    if (data.isEmpty || data.products.isEmpty) {
      return _buildEmptyTable();
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Product Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Revenue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Table Rows
        Expanded(
          child: ListView.builder(
            itemCount: data.products.length,
            itemBuilder: (context, index) {
              final product = data.products[index];
              return _ProductRow(
                product: product,
                rank: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingTable() {
    return Column(
      children: [
        // Loading header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Loading rows
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorTable() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load product data',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTable() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No product sales data available',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product Row Widget ─────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  final TopSellingProduct product;
  final int rank;

  const _ProductRow({
    required this.product,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FuturisticColors.textSecondary.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // Product Name
          Expanded(
            flex: 3,
            child: Text(
              product.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: FuturisticColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Quantity
          Expanded(
            flex: 1,
            child: Text(
              product.qtySold.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FuturisticColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          ),
          
          // Revenue
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format(product.revenueCents),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FuturisticColors.success,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey.shade400; // Silver
      case 3:
        return Colors.brown.shade300; // Bronze
      default:
        return FuturisticColors.textSecondary;
    }
  }
}
