import 'package:flutter/material.dart';
import '../../core/repository/bills_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/currency_service.dart';
import '../../core/responsive/responsive.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/futuristic_colors.dart';

class DashboardMetricsRow extends StatelessWidget {
  const DashboardMetricsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(
        userId: sl<SessionManager>().ownerId ?? '',
      ),
      builder: (context, snapshot) {
        double totalRevenue = 0;
        double paidThisMonth = 0;
        double outstanding = 0;
        double overdue = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final bills = snapshot.data!;

          totalRevenue = bills
              .where((b) => b.status == 'Paid')
              .fold(0, (sum, b) => sum + b.grandTotal);
          paidThisMonth = bills
              .where(
                (b) =>
                    b.status == 'Paid' &&
                    b.date.month == now.month &&
                    b.date.year == now.year,
              )
              .fold(0, (sum, b) => sum + b.grandTotal);
          outstanding = bills
              .where((b) => b.status != 'Paid')
              .fold(0, (sum, b) => sum + (b.grandTotal - b.paidAmount));
          overdue = bills
              .where(
                (b) => b.status != 'Paid' && now.difference(b.date).inDays > 30,
              )
              .fold(0, (sum, b) => sum + (b.grandTotal - b.paidAmount));
        }

        // Build the four metric cards once, then arrange them responsively:
        //   • mobile  → 2×2 grid (each card wide enough to render ₹ values)
        //   • tablet+ → single row of four (original layout)
        // On narrow phones four equal columns leave ~80dp each, which forces ₹
        // amounts to overflow/wrap even at the default text scale.
        final cards = <Widget>[
          _MetricCard(
            title: "Total Revenue",
            value: "${sl<CurrencyService>().symbol}${totalRevenue.toStringAsFixed(0)}",
            color: FuturisticColors.primary,
            icon: Icons.account_balance_wallet,
          ),
          _MetricCard(
            title: "Outstanding",
            value: "${sl<CurrencyService>().symbol}${outstanding.toStringAsFixed(0)}",
            color: FuturisticColors.accent1,
            icon: Icons.pending_actions,
          ),
          _MetricCard(
            title: "Paid This Month",
            value: "${sl<CurrencyService>().symbol}${paidThisMonth.toStringAsFixed(0)}",
            color: FuturisticColors.success,
            icon: Icons.check_circle_outline,
          ),
          _MetricCard(
            title: "Overdue",
            value: "${sl<CurrencyService>().symbol}${overdue.toStringAsFixed(0)}",
            color: FuturisticColors.error,
            icon: Icons.warning_amber,
          ),
        ];

        if (context.isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title is constrained so it can never push into the trailing
              // icon; it ellipsizes instead of overflowing the card.
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FuturisticColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, color: color.withOpacity(0.7), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          // Value scales down (never wraps/overflows) so large ₹ amounts fit
          // the card width at any text scale.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
