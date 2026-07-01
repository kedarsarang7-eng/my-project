import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/insights_service.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// --- NEW PROVIDERS ---

final todaySummaryProvider = FutureProvider((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.fetchTodaySummary();
});

final stockStatusProvider = FutureProvider((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.fetchStockStatus();
});

final salesPerformanceProvider = FutureProvider((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.fetchSalesPerformance();
});

final purchaseVsSaleProvider = FutureProvider((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.fetchPurchaseVsSale();
});

final aiInsightStatsProvider = FutureProvider((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.fetchAiInsight();
});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Business Health',
      subtitle: 'Real-time insights and performance analytics',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh Data',
          onPressed: () {
            // Trigger refresh for all providers by invalidating them
            ref.invalidate(todaySummaryProvider);
            ref.invalidate(stockStatusProvider);
            ref.invalidate(salesPerformanceProvider);
            ref.invalidate(purchaseVsSaleProvider);
            ref.invalidate(aiInsightStatsProvider);
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Today's Summary
          _SectionHeader(title: "Today's Summary", isDark: isDark),
          const SizedBox(height: 12),
          _TodaySummarySection(isDark: isDark),

          const SizedBox(height: 32),

          // 5. AI Insight (Moved up for visibility)
          _SectionHeader(
            title: "Smart Assistant",
            isDark: isDark,
            icon: Icons.psychology,
          ),
          const SizedBox(height: 12),
          _AiInsightSection(isDark: isDark),

          const SizedBox(height: 32),

          // 2. Stock Condition
          _SectionHeader(title: "Stock Condition", isDark: isDark),
          const SizedBox(height: 12),
          _StockConditionSection(isDark: isDark),

          const SizedBox(height: 32),

          // 3. Sales Performance
          _SectionHeader(title: "Sales Performance", isDark: isDark),
          const SizedBox(height: 12),
          _SalesPerformanceSection(isDark: isDark),

          const SizedBox(height: 32),

          // 4. Purchase vs Sale
          _SectionHeader(title: "Purchase vs Sale", isDark: isDark),
          const SizedBox(height: 12),
          _PurchaseVsSaleSection(isDark: isDark),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// --- SECTIONS ---

class _TodaySummarySection extends ConsumerWidget {
  final bool isDark;
  const _TodaySummarySection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(todaySummaryProvider);

    return asyncValue.when(
      data: (either) => either.fold((l) => _ErrorBox(msg: l.message), (data) {
        final sales = (data['total_sales'] ?? 0).toDouble();
        final profit = (data['profit_loss'] ?? 0).toDouble();
        final count = (data['items_sold_count'] ?? 0).toInt();
        final status = data['profit_status'] ?? 'Stable';

        return Row(
          children: [
            Expanded(
              child: _DetailCard(
                title: 'Sales',
                value: '₹${sales.toStringAsFixed(0)}',
                color: Colors.blueAccent,
                icon: Icons.attach_money,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DetailCard(
                title: status, // Profit or Loss
                value: '₹${profit.abs().toStringAsFixed(0)}',
                color: profit >= 0 ? Colors.green : Colors.red,
                icon: profit >= 0 ? Icons.trending_up : Icons.trending_down,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DetailCard(
                title: 'Sold Items',
                value: '$count',
                color: Colors.orangeAccent,
                icon: Icons.shopping_basket,
                isDark: isDark,
              ),
            ),
          ],
        );
      }),
      loading: () => const _LoadingShimmer(height: 100),
      error: (e, _) => _ErrorBox(msg: e.toString()),
    );
  }
}

class _StockConditionSection extends ConsumerWidget {
  final bool isDark;
  const _StockConditionSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(stockStatusProvider);

    return asyncValue.when(
      data: (either) => either.fold((l) => _ErrorBox(msg: l.message), (data) {
        final inStock = data['in_stock_count'] as int? ?? 0;
        final lowStock = data['low_stock_count'] as int? ?? 0;
        final outStock = data['out_of_stock_count'] as int? ?? 0;
        final lowItems = (data['low_stock_items'] as List?) ?? [];
        final outItems = (data['out_of_stock_items'] as List?) ?? [];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StockPill(
                  label: 'In Stock',
                  count: inStock,
                  color: Colors.green,
                ),
                _StockPill(
                  label: 'Low Stock',
                  count: lowStock,
                  color: Colors.orange,
                ),
                _StockPill(
                  label: 'Out of Stock',
                  count: outStock,
                  color: Colors.red,
                ),
              ],
            ),
            if (lowItems.isNotEmpty || outItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (outItems.isNotEmpty)
                _ItemList(
                  title: "🔴 Out of Stock (Action Needed)",
                  items: outItems,
                  isDark: isDark,
                  color: Colors.red,
                ),
              if (lowItems.isNotEmpty)
                _ItemList(
                  title: "🟠 Low Stock (Reorder Soon)",
                  items: lowItems,
                  isDark: isDark,
                  color: Colors.orange,
                ),
            ],
          ],
        );
      }),
      loading: () => const _LoadingShimmer(height: 150),
      error: (e, _) => _ErrorBox(msg: e.toString()),
    );
  }
}

class _SalesPerformanceSection extends ConsumerWidget {
  final bool isDark;
  const _SalesPerformanceSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(salesPerformanceProvider);

    return asyncValue.when(
      data: (either) => either.fold((l) => _ErrorBox(msg: l.message), (data) {
        final top = (data['top_selling'] as List?) ?? [];
        final slow = (data['slow_moving'] as List?) ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (top.isNotEmpty) ...[
              Text(
                "🔥 Top Selling",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: top.length,
                  itemBuilder: (context, index) {
                    final item = top[index];
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['name'] ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              "${item['qty']} sold",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
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
            const SizedBox(height: 16),
            if (slow.isNotEmpty) ...[
              Text(
                "🐌 Slow Moving (Unsold >30d)",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: slow
                    .map(
                      (s) => Chip(
                        label: Text(
                          s.toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      }),
      loading: () => const _LoadingShimmer(height: 150),
      error: (e, _) => _ErrorBox(msg: e.toString()),
    );
  }
}

class _PurchaseVsSaleSection extends ConsumerWidget {
  final bool isDark;
  const _PurchaseVsSaleSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(purchaseVsSaleProvider);

    return asyncValue.when(
      data: (either) => either.fold((l) => _ErrorBox(msg: l.message), (data) {
        final sales = (data['sale_amount'] ?? 0).toDouble();
        final purchases = (data['purchase_amount'] ?? 0).toDouble();

        double maxVal = sales > purchases ? sales : purchases;
        if (maxVal == 0) maxVal = 1;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          opacity: 0.1,
          child: Column(
            children: [
              _BarRow(
                label: "Sales",
                value: sales,
                max: maxVal,
                color: Colors.green,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _BarRow(
                label: "Purchases",
                value: purchases,
                max: maxVal,
                color: Colors.redAccent,
                isDark: isDark,
              ),
            ],
          ),
        );
      }),
      loading: () => const _LoadingShimmer(height: 100),
      error: (e, _) => _ErrorBox(msg: e.toString()),
    );
  }
}

class _AiInsightSection extends ConsumerWidget {
  final bool isDark;
  const _AiInsightSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(aiInsightStatsProvider);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      opacity: 0.15,
      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      child: asyncValue.when(
        data: (text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                SizedBox(width: 8),
                Text(
                  "AI Analysis",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        loading: () => Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text("Gemini is thinking..."),
          ],
        ),
        error: (e, _) =>
            Text("AI Error: $e", style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

// --- WIDGET HELPER CLASSES ---

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final IconData? icon;

  const _SectionHeader({required this.title, required this.isDark, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: isDark ? Colors.white : Colors.black87),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _DetailCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      borderRadius: 12,
      color: color,
      opacity: 0.15,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StockPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ItemList extends StatelessWidget {
  final String title;
  final List items;
  final bool isDark;
  final Color color;

  const _ItemList({
    required this.title,
    required this.items,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black12 : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              final name = item['name'] ?? 'Unknown';
              final qty = item['quantity'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• $name',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '$qty left',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final bool isDark;

  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final widthFactor = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '₹${value.toStringAsFixed(0)}',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  final double height;
  const _LoadingShimmer({this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
