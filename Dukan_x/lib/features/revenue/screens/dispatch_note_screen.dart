import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../widgets/glass_morphism.dart';
import '../models/revenue_models.dart';
import '../services/revenue_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DispatchNoteScreen extends ConsumerStatefulWidget {
  const DispatchNoteScreen({super.key});

  @override
  ConsumerState<DispatchNoteScreen> createState() => _DispatchNoteScreenState();
}

class _DispatchNoteScreenState extends ConsumerState<DispatchNoteScreen>
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
        title: const Text('Dispatch Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Transit'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
        controller: _tabController,
        children: [
          _DispatchListView(
            ownerId: ownerId,
            statuses: [DispatchStatus.pending],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
          ),
          _DispatchListView(
            ownerId: ownerId,
            statuses: [DispatchStatus.inTransit],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
          ),
          _DispatchListView(
            ownerId: ownerId,
            statuses: [DispatchStatus.delivered, DispatchStatus.returned],
            isDark: isDark,
            onStatusChange: _handleStatusChange,
          ),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDispatchSheet(context, ownerId),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('New Dispatch'),
      ),
    );
  }

  Future<void> _handleStatusChange(
    String dispatchId,
    DispatchStatus newStatus,
  ) async {
    final ownerId = sl<SessionManager>().ownerId!;

    String? receiverName;
    if (newStatus == DispatchStatus.delivered) {
      receiverName = await _showReceiverDialog();
      if (receiverName == null) return;
    }

    try {
      await _revenueService.updateDispatchStatus(
        ownerId,
        dispatchId,
        newStatus,
        receiverName: receiverName,
      );
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

  Future<String?> _showReceiverDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter receiver name to confirm delivery'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Receiver Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );
  }

  void _showAddDispatchSheet(BuildContext context, String ownerId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AddDispatchScreen(ownerId: ownerId)),
    );
  }
}

class _DispatchListView extends StatelessWidget {
  final String ownerId;
  final List<DispatchStatus> statuses;
  final bool isDark;
  final Function(String, DispatchStatus) onStatusChange;

  const _DispatchListView({
    required this.ownerId,
    required this.statuses,
    required this.isDark,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DispatchNote>>(
      stream: RevenueService().streamDispatches(ownerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dispatches = snapshot.data!
            .where((d) => statuses.contains(d.status))
            .toList();

        if (dispatches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No dispatches in this category',
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
          itemCount: dispatches.length,
          itemBuilder: (context, index) {
            final dispatch = dispatches[index];
            return _DispatchCard(
              dispatch: dispatch,
              isDark: isDark,
              onStatusChange: onStatusChange,
            );
          },
        );
      },
    );
  }
}

class _DispatchCard extends StatelessWidget {
  final DispatchNote dispatch;
  final bool isDark;
  final Function(String, DispatchStatus) onStatusChange;

  const _DispatchCard({
    required this.dispatch,
    required this.isDark,
    required this.onStatusChange,
  });

  Color _getStatusColor() {
    switch (dispatch.status) {
      case DispatchStatus.pending:
        return Colors.orange;
      case DispatchStatus.inTransit:
        return Colors.blue;
      case DispatchStatus.delivered:
        return Colors.green;
      case DispatchStatus.returned:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (dispatch.status) {
      case DispatchStatus.pending:
        return Icons.schedule;
      case DispatchStatus.inTransit:
        return Icons.local_shipping;
      case DispatchStatus.delivered:
        return Icons.check_circle;
      case DispatchStatus.returned:
        return Icons.undo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

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
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispatch.dispatchNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        dispatch.customerName,
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
                  dispatch.status.name.toUpperCase(),
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

          // Bill Reference
          Row(
            children: [
              const Icon(Icons.receipt, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Bill: ${dispatch.billNumber}',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Vehicle Info
          if (dispatch.vehicleNumber.isNotEmpty ||
              dispatch.driverName.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dispatch.vehicleNumber.isNotEmpty)
                          Text(
                            'Vehicle: ${dispatch.vehicleNumber}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (dispatch.driverName.isNotEmpty)
                          Text(
                            'Driver: ${dispatch.driverName}',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (dispatch.driverPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () async {
                        final uri = Uri.parse('tel:${dispatch.driverPhone}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch dialer'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Delivery Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dispatch.deliveryAddress,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          Text(
            '${dispatch.items.length} items to deliver',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 12,
            ),
          ),
          const Divider(height: 24),

          // Delivered Info
          if (dispatch.status == DispatchStatus.delivered &&
              dispatch.deliveredAt != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivered on ${dateFormat.format(dispatch.deliveredAt!)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dispatch.receiverName != null)
                          Text(
                            'Received by: ${dispatch.receiverName}',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Actions
          if (dispatch.status == DispatchStatus.pending ||
              dispatch.status == DispatchStatus.inTransit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (dispatch.status == DispatchStatus.pending)
                    ElevatedButton.icon(
                      onPressed: () =>
                          onStatusChange(dispatch.id, DispatchStatus.inTransit),
                      icon: const Icon(Icons.local_shipping, size: 18),
                      label: const Text('Start Transit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (dispatch.status == DispatchStatus.inTransit) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          onStatusChange(dispatch.id, DispatchStatus.returned),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Return'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          onStatusChange(dispatch.id, DispatchStatus.delivered),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Add Dispatch Screen
class _AddDispatchScreen extends ConsumerStatefulWidget {
  final String ownerId;

  const _AddDispatchScreen({required this.ownerId});

  @override
  ConsumerState<_AddDispatchScreen> createState() => _AddDispatchScreenState();
}

class _AddDispatchScreenState extends ConsumerState<_AddDispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _revenueService = RevenueService();

  final _vehicleController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedBillId;
  Bill? _selectedBill;
  List<DispatchItem> _dispatchItems = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _vehicleController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _addressController.dispose();
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
        title: const Text('Create Dispatch Note'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Select Bill
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Bill to Dispatch',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _selectBill(isDark),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedBillId != null
                              ? Colors.green
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _selectedBill != null
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedBill!.invoiceNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _selectedBill!.customerName,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_dispatchItems.length} items',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.search, color: Colors.grey),
                                const SizedBox(width: 12),
                                const Text(
                                  'Tap to select a bill',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle & Driver Info
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transport Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleController,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Number',
                      prefixIcon: const Icon(Icons.local_shipping),
                      hintText: 'MH-12-AB-1234',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _driverNameController,
                          decoration: InputDecoration(
                            labelText: 'Driver Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _driverPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Driver Phone',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Address
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter complete delivery address',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.location_on),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) =>
                        val?.isEmpty == true ? 'Address required' : null,
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
                  labelText: 'Dispatch Notes (optional)',
                  hintText: 'Special instructions, handling notes, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedBillId != null && !_isSaving
                    ? _saveDispatch
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_shipping),
                          const SizedBox(width: 8),
                          Text(
                            'Create Dispatch Note',
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

  Future<void> _selectBill(bool isDark) async {
    final result = await sl<BillsRepository>().getAll(userId: widget.ownerId);
    final bills = result.data ?? [];

    if (!mounted) return;

    final selected = await showModalBottomSheet<Bill>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Bill for Dispatch',
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: bills.isEmpty
                  ? const Center(child: Text('No bills found'))
                  : ListView.builder(
                      itemCount: bills.length,
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text(
                            bill.invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(bill.customerName),
                          trailing: Text(
                            '${bill.items.length} items',
                            style: const TextStyle(color: Colors.teal),
                          ),
                          onTap: () {
                            Navigator.pop(ctx, bill);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    setState(() {
      if (selected != null) {
        _selectedBillId = selected.id;
        _selectedBill = selected;

        // Convert bill items to dispatch items
        _dispatchItems = selected.items
            .map(
              (item) => DispatchItem(
                itemId: item.productId,
                itemName: item.productName,
                quantity: item.quantity,
                unit: item.unit,
              ),
            )
            .toList();

        // Pre-fill address if available
        _addressController.text = selected.customerAddress;
      }
    });
  }

  Future<void> _saveDispatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dispatch = DispatchNote(
        id: '',
        ownerId: widget.ownerId,
        billId: _selectedBillId!,
        billNumber: _selectedBill?.invoiceNumber ?? '',
        customerId: _selectedBill?.customerId ?? '',
        customerName: _selectedBill?.customerName ?? '',
        dispatchNumber: '',
        items: _dispatchItems,
        vehicleNumber: _vehicleController.text,
        driverName: _driverNameController.text,
        driverPhone: _driverPhoneController.text,
        deliveryAddress: _addressController.text,
        status: DispatchStatus.pending,
        notes: _notesController.text,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _revenueService.addDispatch(widget.ownerId, dispatch);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispatch note created!'),
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
