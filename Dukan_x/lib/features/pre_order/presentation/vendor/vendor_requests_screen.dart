import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/customer_item_request_repository.dart';
import '../../models/customer_item_request.dart';
import 'vendor_request_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VendorRequestsScreen extends StatelessWidget {
  const VendorRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) {
      return const Center(child: Text("No Shop Context Found"));
    }

    final repo = sl<CustomerItemRequestRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customer Requests',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: StreamBuilder<List<CustomerItemRequest>>(
            stream: repo.watchRequestsForVendor(ownerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No Item Requests",
                        style: GoogleFonts.outfit(
                          fontSize: responsiveValue<double>(
                            context,
                            mobile: 14.0,
                            tablet: 16.0,
                            desktop: 18.0,
                          ),
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return _buildRequestCard(context, req);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, CustomerItemRequest req) {
    final dateStr =
        '${req.createdAt.day}/${req.createdAt.month} ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorRequestDetailScreen(request: req),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusAvatar(req.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer: ${req.customerId.length > 8 ? req.customerId.substring(0, 8) : req.customerId}...',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${req.items.length} Items requested',
                          style: GoogleFonts.outfit(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(req.status),
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAvatar(RequestStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        icon = Icons.priority_high;
        break;
      case RequestStatus.approved:
        color = Colors.blue;
        icon = Icons.thumb_up;
        break;
      case RequestStatus.rejected:
        color = Colors.red;
        icon = Icons.block;
        break;
      case RequestStatus.billed:
        color = Colors.green;
        icon = Icons.check;
        break;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      radius: 20,
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(RequestStatus status) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
