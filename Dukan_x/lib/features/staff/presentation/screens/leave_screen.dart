import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/core/localization/app_l10n.dart';
import '../../data/models/leave_request_model.dart';
import '../widgets/staff_loading_skeleton.dart';

/// Leave Management Screen — displays leave requests with approval workflow.
///
/// Material 3, dark/light mode (Req 14.2).
/// Loading/empty/error states (Req 14.5).
/// Responsive layout (Req 14.3, 14.4).
/// All strings from l10n (Req 14.6).
class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LeaveRequestModel> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _requests = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<LeaveRequestModel> _filteredByStatus(String status) {
    return _requests.where((r) => r.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AppBar(
        title: Text(l10n.staffLeave),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.staffPending),
            Tab(text: l10n.staffApproved),
            Tab(text: l10n.staffRejected),
          ],
        ),
      ),
      body: _isLoading
          ? const StaffLoadingSkeleton(showHeader: false, itemCount: 5)
          : _error != null
          ? StaffErrorState(
              message: l10n.staffErrorLoading,
              onRetry: _loadLeaveRequests,
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaveList(
                  _filteredByStatus('pending'),
                  l10n,
                  colorScheme,
                ),
                _buildLeaveList(
                  _filteredByStatus('approved'),
                  l10n,
                  colorScheme,
                ),
                _buildLeaveList(
                  _filteredByStatus('rejected'),
                  l10n,
                  colorScheme,
                ),
              ],
            ),
    );
  }

  Widget _buildLeaveList(
    List<LeaveRequestModel> requests,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (requests.isEmpty) {
      return StaffEmptyState(
        icon: Icons.event_note,
        title: l10n.staffNoLeaveRequests,
        description: l10n.staffNoLeaveRequestsDesc,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: BoundedBox(
        maxWidth: 800,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildLeaveCard(requests[index], l10n, colorScheme);
          },
        ),
      ),
    );
  }

  Widget _buildLeaveCard(
    LeaveRequestModel request,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AdaptiveText(
                    '${request.from} — ${request.to}',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                  ),
                ),
                _buildLeaveStatusChip(request.status, l10n, colorScheme),
              ],
            ),
            if (request.reason != null) ...[
              const SizedBox(height: 8),
              AdaptiveText(
                request.reason!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
              ),
            ],
            // Approval actions for pending requests
            if (request.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _handleReject(request),
                    child: Text(l10n.staffReject),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _handleApprove(request),
                    child: Text(l10n.staffApprove),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveStatusChip(
    String status,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    Color chipColor;
    String label;
    switch (status) {
      case 'approved':
        chipColor = Colors.green;
        label = l10n.staffApproved;
        break;
      case 'rejected':
        chipColor = colorScheme.error;
        label = l10n.staffRejected;
        break;
      default:
        chipColor = Colors.orange;
        label = l10n.staffPending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleApprove(LeaveRequestModel request) {
    // Approve via provider
  }

  void _handleReject(LeaveRequestModel request) {
    // Reject via provider
  }
}
