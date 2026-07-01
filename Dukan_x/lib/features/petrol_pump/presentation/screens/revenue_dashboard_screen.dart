import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../staff/providers/staff_provider.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Revenue Dashboard Screen for Petrol Pump
/// 
/// Shows comprehensive revenue analytics with charts based on real database records
class RevenueDashboardScreen extends ConsumerStatefulWidget {
  const RevenueDashboardScreen({super.key});

  @override
  ConsumerState<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends ConsumerState<RevenueDashboardScreen> {
  String _selectedPeriod = 'Today';
  final List<String> _periods = ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'This Month'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(staffListProvider.notifier).loadStaffList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final ownerId = session.ownerId ?? '';
    final staffState = ref.watch(staffListProvider);

    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(userId: ownerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bills = snapshot.data ?? [];

        // 1. Filter bills by selected period and businessType = 'petrolPump'
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
        final startOfMonth = DateTime(now.year, now.month, 1);

        final filteredBills = bills.where((b) {
          if (b.businessType != 'petrolPump') return false;
          
          final date = b.date;
          switch (_selectedPeriod) {
            case 'Today':
              return date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart);
            case 'Yesterday':
              return (date.isAfter(yesterdayStart) && date.isBefore(todayStart)) || date.isAtSameMomentAs(yesterdayStart);
            case 'Last 7 Days':
              return date.isAfter(sevenDaysAgo) || date.isAtSameMomentAs(sevenDaysAgo);
            case 'Last 30 Days':
              return date.isAfter(thirtyDaysAgo) || date.isAtSameMomentAs(thirtyDaysAgo);
            case 'This Month':
              return date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth);
            default:
              return true;
          }
        }).toList();

        // 2. Compute metrics
        double totalRevenue = 0;
        int totalTransactions = filteredBills.length;
        double totalLitresSold = 0;
        
        double upiTotal = 0;
        double cashTotal = 0;
        double cardTotal = 0;

        double petrolLitres = 0;
        double petrolRevenue = 0;
        double dieselLitres = 0;
        double dieselRevenue = 0;

        final hourlyRevenue = List<double>.filled(8, 0.0);

        for (var b in filteredBills) {
          totalRevenue += b.grandTotal;

          // Payment mode split
          final mode = b.paymentType.toLowerCase();
          if (mode.contains('upi') || mode.contains('online')) {
            upiTotal += b.grandTotal;
          } else if (mode.contains('card')) {
            cardTotal += b.grandTotal;
          } else {
            cashTotal += b.grandTotal;
          }

          // Fuel details & volume
          for (var item in b.items) {
            totalLitresSold += item.qty;
            final name = item.productName.toLowerCase();
            if (name.contains('petrol') || name.contains('speed') || name.contains('power')) {
              petrolLitres += item.qty;
              petrolRevenue += item.total;
            } else {
              dieselLitres += item.qty;
              dieselRevenue += item.total;
            }
          }

          // Hourly distribution
          final hour = b.date.hour;
          int hourIndex = 0;
          if (hour >= 6 && hour < 8) hourIndex = 0;
          else if (hour >= 8 && hour < 10) hourIndex = 1;
          else if (hour >= 10 && hour < 12) hourIndex = 2;
          else if (hour >= 12 && hour < 14) hourIndex = 3;
          else if (hour >= 14 && hour < 16) hourIndex = 4;
          else if (hour >= 16 && hour < 18) hourIndex = 5;
          else if (hour >= 18 && hour < 20) hourIndex = 6;
          else if (hour >= 20) hourIndex = 7;
          else continue;
          
          hourlyRevenue[hourIndex] += b.grandTotal;
        }

        double avgTicket = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

        // Staff Performance breakdown
        final staffStats = <String, Map<String, dynamic>>{};
        final staffMap = {for (var s in staffState.staff) s.id: s.name};

        for (var b in filteredBills) {
          final attendantId = b.attendantId ?? 'unassigned';
          final staffName = staffMap[attendantId] ?? (attendantId == 'unassigned' ? 'Unassigned' : 'Attendant $attendantId');
          
          final entry = staffStats.putIfAbsent(attendantId, () => {
            'name': staffName,
            'transactions': 0,
            'revenue': 0.0,
          });
          
          entry['transactions'] = (entry['transactions'] as int) + 1;
          entry['revenue'] = (entry['revenue'] as double) + b.grandTotal;
        }

        final sortedStaff = staffStats.entries.toList()
          ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

        final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);

        final content = Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSummaryCards(totalRevenue, totalTransactions, totalLitresSold, avgTicket, currencyFormat),
              const SizedBox(height: 24),
              _buildMainLayout(hourlyRevenue, petrolLitres, petrolRevenue, dieselLitres, dieselRevenue, upiTotal, cashTotal, cardTotal, sortedStaff),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: context.isDesktop
              ? SafeArea(child: content)
              : SafeArea(child: SingleChildScrollView(child: content)),
        );
      },
    );
  }

  Widget _buildHeader() {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Dashboard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your petrol pump performance',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );

    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleColumn,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: _periods.map((period) => DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        titleColumn,
        const Spacer(),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedPeriod,
            borderRadius: BorderRadius.circular(8),
            items: _periods.map((period) => DropdownMenuItem(
              value: period,
              child: Text(period),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedPeriod = value);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double revenue, int transactions, double litresSold, double avgTicket, NumberFormat format) {
    final card1 = _buildSummaryCard(
      'Total Revenue',
      format.format(revenue),
      Icons.currency_rupee,
      AppTheme.primaryColor,
    );
    final card2 = _buildSummaryCard(
      'Transactions',
      transactions.toString(),
      Icons.receipt_long,
      AppTheme.infoColor,
    );
    final card3 = _buildSummaryCard(
      'Fuel Sold',
      '${NumberFormat('#,##,###.#').format(litresSold)} L',
      Icons.local_gas_station,
      AppTheme.successColor,
    );
    final card4 = _buildSummaryCard(
      'Avg. Ticket',
      format.format(avgTicket),
      Icons.trending_up,
      AppTheme.warningColor,
    );

    if (context.isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: [card1, card2, card3, card4],
      );
    } else if (context.isTablet) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
        children: [card1, card2, card3, card4],
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 16),
        Expanded(child: card2),
        const SizedBox(width: 16),
        Expanded(child: card3),
        const SizedBox(width: 16),
        Expanded(child: card4),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 22, desktop: 28),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: responsiveValue<double>(context, mobile: 11, tablet: 12, desktop: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainLayout(
    List<double> hourlyRevenue,
    double petrolLitres,
    double petrolRevenue,
    double dieselLitres,
    double dieselRevenue,
    double upiTotal,
    double cashTotal,
    double cardTotal,
    List<MapEntry<String, Map<String, dynamic>>> sortedStaff,
  ) {
    if (context.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                SizedBox(
                  height: 350,
                  child: _buildHourlySalesCard(hourlyRevenue),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 350,
                  child: _buildFuelSalesBreakdownCard(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildPaymentMethodsCard(upiTotal, cashTotal, cardTotal),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: _buildStaffPerformanceCard(isScrollable: true, sortedStaff: sortedStaff),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile/Tablet scrollable stacked layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 300,
          child: _buildHourlySalesCard(hourlyRevenue),
        ),
        const SizedBox(height: 16),
        _buildFuelSalesBreakdownCard(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
        const SizedBox(height: 16),
        _buildPaymentMethodsCard(upiTotal, cashTotal, cardTotal),
        const SizedBox(height: 16),
        _buildStaffPerformanceCard(isScrollable: false, sortedStaff: sortedStaff),
      ],
    );
  }

  Widget _buildHourlySalesCard(List<double> hourlyRevenue) {
    double maxRevenue = hourlyRevenue.reduce((a, b) => a > b ? a : b);
    if (maxRevenue < 10000) maxRevenue = 10000;
    final maxYValue = (maxRevenue / 10000).ceil() * 10000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Sales',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxYValue,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '₹${value ~/ 1000}k',
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hours = ['6AM', '8AM', '10AM', '12PM', '2PM', '4PM', '6PM', '8PM'];
                          if (value.toInt() < hours.length) {
                            return Text(
                              hours[value.toInt()],
                              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, horizontalInterval: maxYValue / 5),
                  barGroups: List.generate(8, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: hourlyRevenue[index],
                          color: AppTheme.primaryColor,
                          width: responsiveValue<double>(context, mobile: 12, tablet: 18, desktop: 24),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartData _buildPieChartData(double petrolLitres, double petrolRevenue, double dieselLitres, double dieselRevenue) {
    final totalLitres = petrolLitres + dieselLitres;
    final petrolPercent = totalLitres > 0 ? (petrolLitres / totalLitres * 100) : 0.0;
    final dieselPercent = totalLitres > 0 ? (dieselLitres / totalLitres * 100) : 0.0;

    final List<PieChartSectionData> sections = [];
    if (totalLitres == 0) {
      sections.add(
        PieChartSectionData(
          value: 100,
          title: '0%',
          color: Colors.grey.shade600,
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      if (petrolLitres > 0) {
        sections.add(
          PieChartSectionData(
            value: petrolPercent,
            title: '${petrolPercent.toStringAsFixed(0)}%',
            color: const Color(0xFF3B82F6),
            radius: 60,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      if (dieselLitres > 0) {
        sections.add(
          PieChartSectionData(
            value: dieselPercent,
            title: '${dieselPercent.toStringAsFixed(0)}%',
            color: const Color(0xFFF59E0B),
            radius: 60,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 30,
      sections: sections,
    );
  }

  Widget _buildLegendColumn(double petrolLitres, double petrolRevenue, double dieselLitres, double dieselRevenue) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem('Petrol', '${NumberFormat('#,##,###.#').format(petrolLitres)} L', format.format(petrolRevenue), const Color(0xFF3B82F6)),
        const SizedBox(height: 16),
        _buildLegendItem('Diesel', '${NumberFormat('#,##,###.#').format(dieselLitres)} L', format.format(dieselRevenue), const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildFuelSalesBreakdownCard(double petrolLitres, double petrolRevenue, double dieselLitres, double dieselRevenue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Sales Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            context.isMobile
                ? Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: PieChart(
                            _buildPieChartData(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLegendColumn(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: PieChart(
                          _buildPieChartData(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildLegendColumn(petrolLitres, petrolRevenue, dieselLitres, dieselRevenue),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String quantity, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
            Text(quantity, style: const TextStyle(fontSize: 14)),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsCard(double upiTotal, double cashTotal, double cardTotal) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);
    final totalPayment = upiTotal + cashTotal + cardTotal;
    final upiPercent = totalPayment > 0 ? (upiTotal / totalPayment * 100).toStringAsFixed(0) : '0';
    final cashPercent = totalPayment > 0 ? (cashTotal / totalPayment * 100).toStringAsFixed(0) : '0';
    final cardPercent = totalPayment > 0 ? (cardTotal / totalPayment * 100).toStringAsFixed(0) : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Methods',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethodRow('UPI / Online', format.format(upiTotal), '$upiPercent%', const Color(0xFF10B981), Icons.qr_code),
            const SizedBox(height: 12),
            _buildPaymentMethodRow('Cash', format.format(cashTotal), '$cashPercent%', const Color(0xFFF59E0B), Icons.money),
            const SizedBox(height: 12),
            _buildPaymentMethodRow('Card', format.format(cardTotal), '$cardPercent%', const Color(0xFF3B82F6), Icons.credit_card),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow(String label, String amount, String percent, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text(
          percent,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStaffPerformanceCard({required bool isScrollable, required List<MapEntry<String, Map<String, dynamic>>> sortedStaff}) {
    final list = sortedStaff.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No transactions recorded for staff.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(sortedStaff.length > 5 ? 5 : sortedStaff.length, (index) {
              final entry = sortedStaff[index];
              final stats = entry.value;
              final name = stats['name'] as String;
              final txns = '${stats['transactions']} txn';
              final rev = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0).format(stats['revenue']);
              
              Color medalColor = Colors.grey;
              if (index == 0) medalColor = const Color(0xFFFFD700);
              else if (index == 1) medalColor = const Color(0xFFC0C0C0);
              else if (index == 2) medalColor = const Color(0xFFCD7F32);
              
              return _buildStaffPerformanceRow(index + 1, name, txns, rev, medalColor);
            }),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Staff Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isScrollable
                ? Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [list],
                    ),
                  )
                : list,
          ],
        ),
      ),
    );
  }

  Widget _buildStaffPerformanceRow(int rank, String name, String transactions, String revenue, Color medalColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            transactions,
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            revenue,
            style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
