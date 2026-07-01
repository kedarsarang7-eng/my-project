/// Exchange Detail Screen
/// Futuristic UI for viewing exchange details
library;

import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/exchange.dart';
import '../../services/exchange_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ExchangeDetailScreen extends StatefulWidget {
  final String exchangeId;

  const ExchangeDetailScreen({super.key, required this.exchangeId});

  @override
  State<ExchangeDetailScreen> createState() => _ExchangeDetailScreenState();
}

class _ExchangeDetailScreenState extends State<ExchangeDetailScreen> {
  late ExchangeService _exchangeService;
  Exchange? _exchange;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance;
    _exchangeService = ExchangeService(db);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadExchange();
  }

  Future<void> _loadExchange() async {
    final exchange = await _exchangeService.getExchangeById(
      widget.exchangeId,
      userId: _userId!,
    );
    setState(() {
      _exchange = exchange;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: BoundedBox(
          maxWidth: 800,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_exchange == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Exchange not found'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildHeader(isDark),
              SliverToBoxAdapter(child: _buildContent(isDark)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildHeader(bool isDark) {
    final statusColor = _getStatusColor(_exchange!.status);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(_exchange!.status),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    if (_exchange!.isDraft)
                      const PopupMenuItem(
                        value: 'complete',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Complete Exchange'),
                          ],
                        ),
                      ),
                    if (_exchange!.isDraft)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Cancel Exchange'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Exchange number hero
            Container(
              padding: EdgeInsets.all(
                responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 20,
                  desktop: 24,
                ),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _exchange!.exchangeNumber ?? 'Draft Exchange',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 24,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created on ${_formatDate(_exchange!.createdAt)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Info
          _buildInfoCard(
            title: 'Customer',
            icon: Icons.person,
            color: Colors.blue,
            isDark: isDark,
            children: [
              _buildInfoRow('Name', _exchange!.customerName, isDark),
              _buildInfoRow('Phone', _exchange!.customerPhone, isDark),
            ],
          ),
          const SizedBox(height: 16),
          // Device Exchange Visual
          _buildExchangeVisual(isDark),
          const SizedBox(height: 16),
          // Old Device
          _buildInfoCard(
            title: 'Trade-in Device',
            icon: Icons.phone_android,
            color: Colors.orange,
            isDark: isDark,
            children: [
              _buildInfoRow('Device', _exchange!.oldDeviceName, isDark),
              if (_exchange!.oldDeviceBrand != null)
                _buildInfoRow('Brand', _exchange!.oldDeviceBrand!, isDark),
              if (_exchange!.oldDeviceModel != null)
                _buildInfoRow('Model', _exchange!.oldDeviceModel!, isDark),
              if (_exchange!.oldImeiSerial != null)
                _buildInfoRow('IMEI/Serial', _exchange!.oldImeiSerial!, isDark),
              if (_exchange!.oldDeviceCondition != null)
                _buildInfoRow(
                  'Condition',
                  _exchange!.oldDeviceCondition!,
                  isDark,
                ),
              _buildInfoRow(
                'Exchange Value',
                '₹${_exchange!.exchangeValue.toStringAsFixed(0)}',
                isDark,
                valueColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // New Device
          _buildInfoCard(
            title: 'New Device',
            icon: Icons.smartphone,
            color: Colors.green,
            isDark: isDark,
            children: [
              _buildInfoRow('Product', _exchange!.newProductName, isDark),
              if (_exchange!.newImeiSerial != null)
                _buildInfoRow('IMEI/Serial', _exchange!.newImeiSerial!, isDark),
              _buildInfoRow(
                'Price',
                '₹${_exchange!.newDevicePrice.toStringAsFixed(0)}',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Payment Summary
          _buildPaymentSummary(isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildExchangeVisual(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
            const Color(0xFF8B5CF6).withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Old Device',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                Text(
                  '₹${_exchange!.exchangeValue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 24),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smartphone,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New Device',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                Text(
                  '₹${_exchange!.newDevicePrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(isDark ? 0.3 : 0.15),
            const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow(
            'New Device Price',
            '₹${_exchange!.newDevicePrice.toStringAsFixed(0)}',
            isDark,
          ),
          _buildSummaryRow(
            'Exchange Value',
            '- ₹${_exchange!.exchangeValue.toStringAsFixed(0)}',
            isDark,
            valueColor: Colors.green,
          ),
          if (_exchange!.additionalDiscount > 0)
            _buildSummaryRow(
              'Extra Discount',
              '- ₹${_exchange!.additionalDiscount.toStringAsFixed(0)}',
              isDark,
              valueColor: Colors.green,
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount to Pay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                '₹${_exchange!.amountToPay.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 22,
                    tablet: 24,
                    desktop: 28,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount Paid',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                '₹${_exchange!.amountPaid.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          if (_exchange!.balanceAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Balance Due', style: TextStyle(color: Colors.red)),
                Text(
                  '₹${_exchange!.balanceAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ExchangeStatus status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    if (!_exchange!.isDraft) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showPaymentDialog,
              icon: const Icon(Icons.payment),
              label: const Text('Record Payment'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: isDark ? Colors.white38 : const Color(0xFF6366F1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _completeExchange,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  'Complete',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ExchangeStatus status) {
    switch (status) {
      case ExchangeStatus.draft:
        return const Color(0xFFF59E0B);
      case ExchangeStatus.completed:
        return const Color(0xFF10B981);
      case ExchangeStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'complete':
        _completeExchange();
        break;
      case 'cancel':
        _cancelExchange();
        break;
    }
  }

  Future<void> _completeExchange() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Exchange?'),
        content: const Text(
          'This will mark the exchange as completed and add the old device to your inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _exchangeService.completeExchange(
        exchangeId: widget.exchangeId,
        userId: _userId!,
      );
      _loadExchange();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exchange completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelExchange() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Exchange?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _exchangeService.cancelExchange(
        widget.exchangeId,
        userId: _userId!,
      );
      _loadExchange();
    }
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController(
      text: _exchange!.balanceAmount.toStringAsFixed(0),
    );
    String paymentMode = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record Payment',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildPaymentModeOption(
                          'Cash',
                          Icons.money,
                          paymentMode == 'Cash',
                          isDark,
                          () => setModalState(() => paymentMode = 'Cash'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentModeOption(
                          'Online',
                          Icons.phonelink_rounded,
                          paymentMode == 'Online',
                          isDark,
                          () => setModalState(() => paymentMode = 'Online'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount > 0) {
                      await _exchangeService.recordPayment(
                        exchangeId: widget.exchangeId,
                        userId: _userId!,
                        amount: amount,
                        paymentMode: paymentMode,
                      );
                      _loadExchange();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Record Payment'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentModeOption(
    String label,
    IconData icon,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.15)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
