// ============================================================================
// Computer Shop — Serial History Screen
// ============================================================================
// View complete service history for a serial number:
// - Product details
// - All job cards associated with the serial
// - RMA history
// - Warranty information
// Timeline visualization
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../../providers/computer_job_providers.dart';
import '../../data/repositories/computer_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class SerialHistoryScreen extends ConsumerStatefulWidget {
  final String serialNumber;

  const SerialHistoryScreen({super.key, required this.serialNumber});

  @override
  ConsumerState<SerialHistoryScreen> createState() =>
      _SerialHistoryScreenState();
}

class _SerialHistoryScreenState extends ConsumerState<SerialHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(serialHistoryProvider(widget.serialNumber));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Serial History',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              widget.serialNumber,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              // Show QR code or barcode for serial
            },
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: historyAsync.when(
          data: (history) => _HistoryContent(history: history),
          loading: () => const _LoadingState(),
          error: (error, stack) => _ErrorState(
            error: error.toString(),
            onRetry: () =>
                ref.refresh(serialHistoryProvider(widget.serialNumber)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// History Content
// ============================================================================

class _HistoryContent extends StatelessWidget {
  final ComputerSerialHistory history;

  const _HistoryContent({required this.history});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Info Card
          _ProductInfoCard(serial: history.serial),
          const SizedBox(height: 20),

          // Warranty Card
          if (history.warranty != null)
            _WarrantyInfoCard(warranty: history.warranty!),
          if (history.warranty != null) const SizedBox(height: 20),

          // Service History Timeline
          if (history.jobCards.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.build,
              title: 'Service History',
              subtitle: '${history.jobCards.length} service record(s)',
            ),
            const SizedBox(height: 16),
            _ServiceTimeline(jobs: history.jobCards),
          ],

          // RMA History
          if (history.rmas.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.assignment_return,
              title: 'RMA History',
              subtitle: '${history.rmas.length} RMA record(s)',
            ),
            const SizedBox(height: 16),
            _RMAList(rmas: history.rmas),
          ],

          // No History State
          if (history.jobCards.isEmpty && history.rmas.isEmpty)
            _EmptyHistoryState(
              serialNumber: history.serial['serialNumber'] ?? '',
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Product Info Card
// ============================================================================

class _ProductInfoCard extends StatelessWidget {
  final Map<String, dynamic> serial;

  const _ProductInfoCard({required this.serial});

  @override
  Widget build(BuildContext context) {
    final soldAt = serial['soldAt'] != null
        ? DateTime.tryParse(serial['soldAt'])
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.computer,
                    color: Color(0xFF3B82F6),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serial['productName'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product ID: ${serial['productId'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _InfoRow('Serial Number', serial['serialNumber'] ?? 'N/A'),
            const SizedBox(height: 8),
            _InfoRow(
              'Invoice',
              serial['invoiceNumber'] ?? serial['invoiceId'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              'Date Sold',
              soldAt != null ? DateFormat('dd MMM yyyy').format(soldAt) : 'N/A',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Warranty Info Card
// ============================================================================

class _WarrantyInfoCard extends StatelessWidget {
  final ComputerWarranty warranty;

  const _WarrantyInfoCard({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final isExpired = warranty.isExpired ?? false;
    final daysRemaining = warranty.daysRemaining ?? 0;
    final statusColor = isExpired
        ? Colors.red
        : (daysRemaining < 30 ? Colors.orange : Colors.green);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Warranty ${warranty.status}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                if (!isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$daysRemaining days left',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              'Expires',
              warranty.warrantyExpiryDate,
              valueColor: isExpired ? Colors.red : null,
            ),
            const SizedBox(height: 8),
            _InfoRow('Period', '${warranty.warrantyPeriodMonths} months'),
            const SizedBox(height: 8),
            _InfoRow('Claims', '${warranty.claimCount}'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Service Timeline
// ============================================================================

class _ServiceTimeline extends StatelessWidget {
  final List<ComputerJobCard> jobs;

  const _ServiceTimeline({required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FixedTimeline.tileBuilder(
          theme: TimelineThemeData(
            nodePosition: 0.15,
            color: Colors.grey.shade300,
          ),
          builder: TimelineTileBuilder.connected(
            contentsAlign: ContentsAlign.basic,
            oppositeContentsBuilder: (context, index) {
              final job = jobs[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  DateFormat('dd MMM\nyyyy').format(job.createdAt),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              );
            },
            contentsBuilder: (context, index) {
              final job = jobs[index];
              return _TimelineJobCard(job: job);
            },
            connectorBuilder: (context, index, type) {
              return SolidLineConnector(
                color: index < jobs.length - 1
                    ? const Color(0xFF3B82F6).withOpacity(0.3)
                    : Colors.transparent,
                thickness: 2,
              );
            },
            indicatorBuilder: (context, index) {
              return DotIndicator(
                size: 16,
                color: const Color(0xFF3B82F6),
                border: Border.all(color: Colors.white, width: 2),
              );
            },
            itemCount: jobs.length,
          ),
        ),
      ),
    );
  }
}

class _TimelineJobCard extends StatelessWidget {
  final ComputerJobCard job;

  const _TimelineJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
    );
    final statusColor = _getStatusColor(job.status);

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 20),
      child: InkWell(
        onTap: () {
          context.push(
            '/computer-shop/job-card-detail',
            extra: {'jobId': job.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (job.actualLaborCost != null ||
                      job.actualPartsCost != null)
                    Text(
                      currencyFormat.format(
                        (job.actualLaborCost ?? 0) + (job.actualPartsCost ?? 0),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (job.diagnosis != null)
                Text(
                  job.diagnosis!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                )
              else
                Text(
                  job.reportedIssue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              if (job.technicianName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      job.technicianName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'INTAKE':
        return Colors.orange;
      case 'DIAGNOSIS':
        return Colors.amber;
      case 'AWAITING_PARTS':
        return Colors.deepOrange;
      case 'REPAIRING':
        return Colors.blue;
      case 'QC':
        return Colors.purple;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// RMA List
// ============================================================================

class _RMAList extends StatelessWidget {
  final List<Map<String, dynamic>> rmas;

  const _RMAList({required this.rmas});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rmas.map((rma) {
        final status = rma['status'] as String? ?? 'INITIATED';
        final statusColor = _getRMAStatusColor(status);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment_return, color: statusColor),
            ),
            title: Text(
              rma['reason'] ?? 'RMA Request',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Brand: ${rma['brand'] ?? 'N/A'}'),
                if (rma['oemRmaNumber'] != null)
                  Text('OEM RMA: ${rma['oemRmaNumber']}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getRMAStatusColor(String status) {
    switch (status) {
      case 'INITIATED':
        return Colors.orange;
      case 'SHIPPED_TO_OEM':
        return Colors.blue;
      case 'REPLACEMENT_RECEIVED':
        return Colors.green;
      case 'REJECTED_BY_OEM':
        return Colors.red;
      case 'RESOLVED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// Section Header
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Info Row
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Empty History State
// ============================================================================

class _EmptyHistoryState extends StatelessWidget {
  final String serialNumber;

  const _EmptyHistoryState({required this.serialNumber});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Service History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This serial number has no recorded service history yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/computer-shop/create-job-card',
                  extra: {'serialNumber': serialNumber},
                );
              },
              icon: const Icon(Icons.build),
              label: const Text('Create Service Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Loading & Error States
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading serial history...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Failed to Load History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
