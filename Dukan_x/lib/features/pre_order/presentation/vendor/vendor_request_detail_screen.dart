import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/customer_item_request_repository.dart';
import '../../models/customer_item_request.dart';
import '../../services/pre_order_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VendorRequestDetailScreen extends StatefulWidget {
  final CustomerItemRequest request;
  const VendorRequestDetailScreen({required this.request, super.key});

  @override
  State<VendorRequestDetailScreen> createState() =>
      _VendorRequestDetailScreenState();
}

class _VendorRequestDetailScreenState extends State<VendorRequestDetailScreen> {
  late CustomerItemRequest _request;
  final PreOrderService _service = sl<PreOrderService>();
  final CustomerItemRequestRepository _repo =
      sl<CustomerItemRequestRepository>();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  // --- Actions ---

  Future<void> _updateItemStatus(int index, ItemStatus status) async {
    final updatedItems = List<CustomerItemRequestItem>.from(_request.items);
    double approvedQty = updatedItems[index].approvedQty;

    if (status == ItemStatus.approved && approvedQty <= 0) {
      approvedQty = updatedItems[index].requestedQty;
    }

    updatedItems[index] = updatedItems[index].copyWith(
      status: status,
      approvedQty: approvedQty,
    );

    await _updateRequest(_request.copyWith(items: updatedItems));
  }

  Future<void> _updateApprovedQty(int index, double qty) async {
    final updatedItems = List<CustomerItemRequestItem>.from(_request.items);
    updatedItems[index] = updatedItems[index].copyWith(approvedQty: qty);
    await _updateRequest(_request.copyWith(items: updatedItems));
  }

  Future<void> _updateRequest(CustomerItemRequest newRequest) async {
    try {
      await _repo.updateRequest(newRequest);
      setState(() => _request = newRequest);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _createBill() async {
    setState(() => _isLoading = true);
    try {
      await _service.createBillFromRequest(_request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill Created & Stock Adjusted!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create Bill: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final canCreateBill = _request.items.any(
      (i) => i.status == ItemStatus.approved && i.approvedQty > 0,
    );
    final isBilled = _request.status == RequestStatus.billed;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              _buildCustomerInfoCard(),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: _request.items.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _request.items[i];
                    return _buildItemRow(item, i, isBilled);
                  },
                ),
              ),
              if (!isBilled) _buildStickyActionFooter(canCreateBill),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer ID',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _request.customerId.length > 10
                        ? _request.customerId.substring(0, 10)
                        : _request.customerId,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              _buildStatusBadge(_request.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    CustomerItemRequestItem item,
    int index,
    bool isReadOnly,
  ) {
    final isApproved = item.status == ItemStatus.approved;
    final isRejected = item.status == ItemStatus.cancelled;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            child: Icon(
              isRejected
                  ? Icons.cancel
                  : (isApproved ? Icons.check_circle : Icons.circle_outlined),
              color: isRejected
                  ? Colors.red
                  : (isApproved ? Colors.green : Colors.grey),
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Requested: ',
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    Text(
                      '${item.requestedQty} ${item.unit}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (isApproved)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Text(
                          'Approved: ',
                          style: GoogleFonts.outfit(color: Colors.green),
                        ),
                        Text(
                          '${item.approvedQty} ${item.unit}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isReadOnly)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isRejected)
                  Row(
                    children: [
                      if (!isApproved)
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          tooltip: 'Approve',
                          onPressed: () =>
                              _updateItemStatus(index, ItemStatus.approved),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                        onPressed: () =>
                              _updateItemStatus(index, ItemStatus.cancelled),
                      ),
                    ],
                  ),
                if (isApproved)
                  OutlinedButton(
                    onPressed: () => _showEditQtyDialog(index, item),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Edit Qty'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStickyActionFooter(bool canCreateBill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (canCreateBill && !_isLoading) ? _createBill : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'CREATE BILL & PROCESS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  void _showEditQtyDialog(int index, CustomerItemRequestItem item) {
    final controller = TextEditingController(text: item.approvedQty.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Quantity: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Approved Quantity (${item.unit})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                _updateApprovedQty(index, val);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color color;
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        break;
      case RequestStatus.approved:
        color = Colors.blue;
        break;
      case RequestStatus.rejected:
        color = Colors.red;
        break;
      case RequestStatus.billed:
        color = Colors.green;
        break;
    }
    return Chip(
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
