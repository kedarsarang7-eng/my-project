import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';

/// Customer Loyalty Widget — Task 13.2 (Requirements 9.4–9.8, 1.8)
///
/// Displays customer lookup by mobile number and REAL loyalty points balance
/// (from the Drift Customers.loyaltyPoints column, NOT customer.totalPaid).
///
/// Features:
/// - Real loyalty balance from the Drift Customers table
/// - Redemption input: operator enters points to redeem against the bill
/// - Validation: redemption exceeding available balance is rejected
/// - Redemption applies to bill total in integer Paise (1 point = ₹1 = 100 Paise)
///
/// Accrual rule: 1 loyalty point per ₹100 spent (rounded down).
/// Accrual is triggered by the parent POS screen after a successful sale.
///
/// Data flow: Mobile lookup → Customers table → loyaltyPoints field → POS display
class CustomerLoyaltyWidget extends StatefulWidget {
  final bool isDark;
  final Color accent;
  final String? customerName;
  final int loyaltyPoints;

  /// Called when a customer is selected or cleared.
  /// [id] — customer id, [name] — customer name, [points] — real loyalty points.
  final Function(String id, String name, int points) onCustomerSelected;

  /// Called when the operator confirms a points redemption.
  /// [pointsToRedeem] — the number of points to redeem (1 point = ₹1 = 100 Paise discount).
  /// Returns true if the redemption was accepted, false if rejected.
  final Future<bool> Function(int pointsToRedeem)? onRedeemPoints;

  const CustomerLoyaltyWidget({
    super.key,
    required this.isDark,
    required this.accent,
    this.customerName,
    this.loyaltyPoints = 0,
    required this.onCustomerSelected,
    this.onRedeemPoints,
  });

  @override
  State<CustomerLoyaltyWidget> createState() => _CustomerLoyaltyWidgetState();
}

class _CustomerLoyaltyWidgetState extends State<CustomerLoyaltyWidget> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _redeemController = TextEditingController();
  String? _redeemError;
  bool _isRedeeming = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _redeemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.person_search_rounded, color: widget.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Customer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Phone Search
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter mobile number...',
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.white30 : Colors.grey.shade400,
              fontSize: 12,
            ),
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: widget.accent.withValues(alpha: 0.5),
              size: 18,
            ),
            suffixIcon: IconButton(
              onPressed: _searchCustomer,
              icon: Icon(Icons.search_rounded, color: widget.accent, size: 18),
              tooltip: 'Search customer',
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8F6FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
          onSubmitted: (_) => _searchCustomer(),
        ),
        const SizedBox(height: 8),

        // Customer Card (if selected)
        if (widget.customerName != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.accent.withValues(alpha: 0.08),
                  widget.accent.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.accent.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: widget.accent.withValues(alpha: 0.15),
                      child: Text(
                        widget.customerName![0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customerName!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            _phoneController.text,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.onCustomerSelected('', '', 0);
                        _phoneController.clear();
                        _redeemController.clear();
                        setState(() => _redeemError = null);
                      },
                      icon: const Icon(Icons.close, size: 16),
                      color: widget.isDark
                          ? Colors.white38
                          : Colors.grey.shade400,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),

                // Loyalty Points Display
                if (widget.loyaltyPoints > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.loyaltyPoints} Loyalty Points',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(₹${widget.loyaltyPoints} value)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Redemption Input (only if customer has points and callback is provided)
                if (widget.loyaltyPoints > 0 &&
                    widget.onRedeemPoints != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _redeemController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Points to redeem...',
                            hintStyle: TextStyle(
                              color: widget.isDark
                                  ? Colors.white30
                                  : Colors.grey.shade400,
                              fontSize: 11,
                            ),
                            prefixIcon: Icon(
                              Icons.redeem_rounded,
                              color: Colors.amber.shade600,
                              size: 16,
                            ),
                            errorText: _redeemError,
                            errorStyle: const TextStyle(fontSize: 10),
                            filled: true,
                            fillColor: widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.amber.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _isRedeeming ? null : _handleRedeem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isRedeeming
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Redeem',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1 point = ₹1 discount. Max: ${widget.loyaltyPoints} pts',
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.isDark
                          ? Colors.white30
                          : Colors.grey.shade500,
                    ),
                  ),
                ],

                // Zero points message
                if (widget.loyaltyPoints == 0 &&
                    widget.customerName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.white : Colors.grey)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          color: widget.isDark
                              ? Colors.white38
                              : Colors.grey.shade500,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '0 Loyalty Points',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Handles the "Redeem" button press.
  /// Validates that redemption does not exceed available balance (Requirement 9.7).
  void _handleRedeem() async {
    final text = _redeemController.text.trim();
    if (text.isEmpty) {
      setState(() => _redeemError = 'Enter points to redeem');
      return;
    }

    final pointsToRedeem = int.tryParse(text) ?? 0;
    if (pointsToRedeem <= 0) {
      setState(() => _redeemError = 'Enter a positive number');
      return;
    }

    // Validation: redemption exceeding available balance is REJECTED (9.7)
    if (pointsToRedeem > widget.loyaltyPoints) {
      setState(
        () => _redeemError =
            'Exceeds available balance (${widget.loyaltyPoints} pts)',
      );
      return;
    }

    setState(() {
      _redeemError = null;
      _isRedeeming = true;
    });

    final accepted = await widget.onRedeemPoints!(pointsToRedeem);
    if (!mounted) return;

    if (accepted) {
      _redeemController.clear();
      setState(() => _isRedeeming = false);
    } else {
      setState(() {
        _isRedeeming = false;
        _redeemError = 'Redemption rejected — try a lower amount';
      });
    }
  }

  /// Searches for a customer by phone and retrieves REAL loyalty points
  /// from the Drift Customers.loyaltyPoints column (NOT customer.totalPaid).
  void _searchCustomer() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) return;

    final result = await customersRepository.getByPhone(phone);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final customer = result.data!;

      // Fetch REAL loyalty points from the Drift Customers table (Req 9.4).
      // Query the Drift table directly for the loyaltyPoints column since
      // the Customer domain model doesn't expose it.
      int realPoints = 0;
      try {
        final db = sl<AppDatabase>();
        final row = await (db.select(
          db.customers,
        )..where((t) => t.phone.equals(phone))).getSingleOrNull();
        realPoints = row?.loyaltyPoints ?? 0;
      } catch (_) {
        // If the query fails, default to 0 — never use totalPaid as proxy.
        realPoints = 0;
      }

      widget.onCustomerSelected(
        customer.id,
        customer.name,
        realPoints, // Real loyalty balance — NOT customer.totalPaid (F17)
      );
    } else {
      // Customer not found — show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No customer found for $phone'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
