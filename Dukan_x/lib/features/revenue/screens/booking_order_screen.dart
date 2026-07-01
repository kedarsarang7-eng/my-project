// Booking Order Screen - Manage advance bookings with delivery tracking
//
// Author: DukanX Team
// Created: 2024-12-25

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../widgets/glass_morphism.dart';
import '../models/revenue_models.dart';
import '../services/revenue_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BookingOrderScreen extends ConsumerStatefulWidget {
  const BookingOrderScreen({super.key});

  @override
  ConsumerState<BookingOrderScreen> createState() => _BookingOrderScreenState();
}

class _BookingOrderScreenState extends ConsumerState<BookingOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _revenueService = RevenueService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final ownerId = sl<SessionManager>().ownerId ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Booking Orders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Ready'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
        controller: _tabController,
        children: [
          _BookingListView(
            ownerId: ownerId,
            statuses: [BookingStatus.pending, BookingStatus.confirmed],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
            onConvert: _handleConvert,
          ),
          _BookingListView(
            ownerId: ownerId,
            statuses: [BookingStatus.ready],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
            onConvert: _handleConvert,
          ),
          _BookingListView(
            ownerId: ownerId,
            statuses: [
              BookingStatus.delivered,
              BookingStatus.converted,
              BookingStatus.cancelled,
            ],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
            onConvert: _handleConvert,
          ),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBookingSheet(context, ownerId, isDark),
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),
    );
  }

  Future<void> _handleStatusChange(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    final ownerId = sl<SessionManager>().ownerId!;
    try {
      await _revenueService.updateBookingStatus(ownerId, bookingId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleConvert(String bookingId) async {
    final ownerId = sl<SessionManager>().ownerId!;
    try {
      await _revenueService.convertBookingToSale(ownerId, bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking converted to Invoice!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddBookingSheet(BuildContext context, String ownerId, bool isDark) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AddBookingScreen(ownerId: ownerId)),
    );
  }
}

class _BookingListView extends StatelessWidget {
  final String ownerId;
  final List<BookingStatus> statuses;
  final bool isDark;
  final Function(String, BookingStatus) onStatusChange;
  final Function(String) onConvert;

  const _BookingListView({
    required this.ownerId,
    required this.statuses,
    required this.isDark,
    required this.onStatusChange,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BookingOrder>>(
      stream: RevenueService().streamBookings(ownerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!
            .where((b) => statuses.contains(b.status))
            .toList();

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No bookings in this category',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _BookingCard(
              booking: booking,
              isDark: isDark,
              onStatusChange: onStatusChange,
              onConvert: onConvert,
            );
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingOrder booking;
  final bool isDark;
  final Function(String, BookingStatus) onStatusChange;
  final Function(String) onConvert;

  const _BookingCard({
    required this.booking,
    required this.isDark,
    required this.onStatusChange,
    required this.onConvert,
  });

  Color _getStatusColor() {
    switch (booking.status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.ready:
        return Colors.purple;
      case BookingStatus.delivered:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.converted:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'â‚¹',
      decimalDigits: 0,
    );
    final isOverdue =
        booking.deliveryDate.isBefore(DateTime.now()) &&
        ![
          BookingStatus.delivered,
          BookingStatus.cancelled,
          BookingStatus.converted,
        ].contains(booking.status);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_note,
                      color: _getStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.bookingNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        booking.customerName,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Delivery Date
          Row(
            children: [
              Icon(
                Icons.local_shipping,
                size: 18,
                color: isOverdue ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivery: ${dateFormat.format(booking.deliveryDate)}',
                style: TextStyle(
                  color: isOverdue
                      ? Colors.red
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OVERDUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Items Preview
          ...booking.items
              .take(2)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.itemName} x ${item.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      Text(
                        currencyFormat.format(item.amount),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (booking.items.length > 2)
            Text(
              '+ ${booking.items.length - 2} more items',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          const Divider(height: 24),

          // Amount Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${currencyFormat.format(booking.totalAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Advance: ${currencyFormat.format(booking.advanceAmount)}',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Balance: ${currencyFormat.format(booking.balanceAmount)}',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              // Action buttons
              if (booking.status == BookingStatus.pending)
                IconButton(
                  onPressed: () =>
                      onStatusChange(booking.id, BookingStatus.confirmed),
                  icon: Icon(Icons.check, color: Colors.green),
                  tooltip: 'Confirm',
                ),
              if (booking.status == BookingStatus.confirmed)
                IconButton(
                  onPressed: () =>
                      onStatusChange(booking.id, BookingStatus.ready),
                  icon: Icon(Icons.inventory_2, color: Colors.purple),
                  tooltip: 'Mark Ready',
                ),
              if (booking.status == BookingStatus.ready)
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          onStatusChange(booking.id, BookingStatus.delivered),
                      icon: Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Mark Delivered',
                    ),
                    IconButton(
                      onPressed: () => onConvert(booking.id),
                      icon: Icon(Icons.receipt_long, color: Colors.blue),
                      tooltip: 'Convert to Invoice',
                    ),
                  ],
                ),
            ],
          ),

          // Notes
          if (booking.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      booking.notes,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Add Booking Screen
class _AddBookingScreen extends ConsumerStatefulWidget {
  final String ownerId;

  const _AddBookingScreen({required this.ownerId});

  @override
  ConsumerState<_AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends ConsumerState<_AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _revenueService = RevenueService();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _advanceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));
  final List<BookingItem> _items = [];
  bool _isSaving = false;

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.amount);
  double get _advanceAmount => double.tryParse(_advanceController.text) ?? 0;
  double get _balanceAmount => _totalAmount - _advanceAmount;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _addressController.dispose();
    _advanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('New Booking'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Details
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) =>
                        val?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Delivery Address',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Date
            GlassCard(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _deliveryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _deliveryDate = date);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Date',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'EEEE, dd MMM yyyy',
                            ).format(_deliveryDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddItemDialog(isDark),
                        icon: Icon(Icons.add),
                        label: Text('Add Item'),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No items added',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.itemName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity.toStringAsFixed(0)} ${item.unit} Ã— â‚¹${item.rate.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'â‚¹${item.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _items.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'â‚¹${_totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _advanceController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Advance Paid',
                            prefixText: 'â‚¹ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Due',
                          style: TextStyle(color: Colors.orange),
                        ),
                        Text(
                          'â‚¹${_balanceAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            GlassCard(
              child: TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _items.isNotEmpty && !_isSaving
                    ? _saveBooking
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check),
                          const SizedBox(width: 8),
                          Text(
                            'Create Booking',
                            style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  )),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(bool isDark) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Rate (â‚¹)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              final rate = double.tryParse(rateController.text) ?? 0;
              if (nameController.text.isNotEmpty && qty > 0 && rate > 0) {
                setState(() {
                  _items.add(
                    BookingItem(
                      itemId: DateTime.now().millisecondsSinceEpoch.toString(),
                      itemName: nameController.text,
                      quantity: qty,
                      rate: rate,
                      amount: qty * rate,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final booking = BookingOrder(
        id: '',
        ownerId: widget.ownerId,
        customerId: '', // Will be looked up or created
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text,
        bookingNumber: '', // Generated by service
        items: _items,
        totalAmount: _totalAmount,
        advanceAmount: _advanceAmount,
        balanceAmount: _balanceAmount,
        deliveryDate: _deliveryDate,
        deliveryAddress: _addressController.text,
        status: BookingStatus.pending,
        notes: _notesController.text,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _revenueService.addBooking(widget.ownerId, booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
