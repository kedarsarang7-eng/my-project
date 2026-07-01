import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'enterprise_table.dart';

/// Premium Recent Transactions Table with glassmorphism styling.
/// Displays real transaction data with enhanced status badges and visual effects.
class RecentTransactionsTable extends StatelessWidget {
  final List<dynamic> transactions;
  final VoidCallback onViewAll;

  const RecentTransactionsTable({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.cardColor, theme.cardColor.withOpacity(0.95)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? primaryColor.withOpacity(0.2) : theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? primaryColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with View All button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Recent Transactions",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              // View All button with hover effect
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "View All",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Table content
          Expanded(
            child: EnterpriseTable(
              columns: [
                EnterpriseTableColumn(
                  title: "Invoice #",
                  valueBuilder: (item) => (item as Map)['id'],
                  widgetBuilder: (item) {
                    final id = (item as Map)['id'];
                    return Text(
                      id,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                EnterpriseTableColumn(
                  title: "Customer",
                  valueBuilder: (item) => (item as Map)['customer'],
                  widgetBuilder: (item) {
                    final customer = (item as Map)['customer'];
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: primaryColor.withOpacity(
                            0.2,
                          ),
                          child: Text(
                            customer.isNotEmpty
                                ? customer[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            customer,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                EnterpriseTableColumn(
                  title: "Amount",
                  valueBuilder: (item) => (item as Map)['amount'],
                  isNumeric: true,
                  widgetBuilder: (item) {
                    final amount = (item as Map)['amount'];
                    return Text(
                      amount,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                EnterpriseTableColumn(
                  title: "Status",
                  valueBuilder: (item) => (item as Map)['status'],
                  widgetBuilder: (item) => _buildStatusBadge(context, item),
                ),
              ],
              // DATA INTEGRITY: Only show REAL transactions - NO mock data
              data: transactions,
              rowsPerPage: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final status = (item as Map)['status'];
    Color color;
    IconData icon;

    switch (status) {
      case 'Paid':
        color = const Color(0xFF22C55E); // Green 500
        icon = Icons.check_circle;
        break;
      case 'Pending':
        color = const Color(0xFFF59E0B); // Amber 500
        icon = Icons.schedule;
        break;
      case 'Unpaid':
        color = const Color(0xFFEF4444); // Red 500
        icon = Icons.error_outline;
        break;
      default:
        color = theme.hintColor;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
