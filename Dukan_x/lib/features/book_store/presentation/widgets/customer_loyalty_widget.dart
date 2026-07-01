import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';

/// Customer Loyalty Widget
///
/// Displays customer lookup by mobile number and loyalty points.
/// Integrates with Customers table for CRM.
///
/// Data flow: Mobile lookup → Customers table → loyaltyPoints field → POS display
class CustomerLoyaltyWidget extends StatefulWidget {
  final bool isDark;
  final Color accent;
  final String? customerName;
  final int loyaltyPoints;
  final Function(String id, String name, int points) onCustomerSelected;

  const CustomerLoyaltyWidget({
    super.key,
    required this.isDark,
    required this.accent,
    this.customerName,
    this.loyaltyPoints = 0,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerLoyaltyWidget> createState() => _CustomerLoyaltyWidgetState();
}

class _CustomerLoyaltyWidgetState extends State<CustomerLoyaltyWidget> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
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

  void _searchCustomer() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) return;

    final result = await customersRepository.getByPhone(phone);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final customer = result.data!;
      widget.onCustomerSelected(
        customer.id,
        customer.name,
        customer.totalPaid.toInt(), // Use totalPaid as loyalty proxy
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
