import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/marketing_repository.dart';
import '../../data/models/campaign_model.dart';
import 'create_campaign_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Campaigns List Screen
///
/// Displays all marketing campaigns with status and stats.
class CampaignsListScreen extends StatefulWidget {
  const CampaignsListScreen({super.key});

  @override
  State<CampaignsListScreen> createState() => _CampaignsListScreenState();
}

class _CampaignsListScreenState extends State<CampaignsListScreen> {
  final _repository = sl<MarketingRepository>();

  List<CampaignModel> _campaigns = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await _repository.getAllCampaigns(
      userId: userId,
      status: _filterStatus == 'all' ? null : _filterStatus.toUpperCase(),
    );

    if (result.isSuccess) {
      setState(() {
        _campaigns = result.data!;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Marketing Campaigns'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(isDark),

          const SizedBox(height: 8),

          // Filter Tabs
          _buildFilterTabs(isDark),

          // Campaign List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _campaigns.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadCampaigns,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _campaigns.length,
                      itemBuilder: (_, i) =>
                          _buildCampaignCard(_campaigns[i], isDark),
                    ),
                  ),
          ),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
          );
          if (result == true) _loadCampaigns();
        },
        icon: const Icon(Icons.campaign),
        label: const Text('New Campaign'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    int total = _campaigns.length;
    int running = _campaigns
        .where((c) => c.status == CampaignStatus.running)
        .length;
    int sent = _campaigns.fold(0, (sum, c) => sum + c.sentCount);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Total',
            total.toString(),
            Icons.campaign,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Running',
            running.toString(),
            Icons.play_circle,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Messages',
            sent.toString(),
            Icons.message,
            Colors.purple,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final tabs = ['all', 'draft', 'scheduled', 'running', 'completed'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _filterStatus == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tab == 'all' ? 'All' : tab.toUpperCase()),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _filterStatus = tab);
                _loadCampaigns();
              },
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCampaignCard(CampaignModel campaign, bool isDark) {
    final statusColor = _getStatusColor(campaign.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getTypeColor(campaign.type).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(campaign.type),
                    color: _getTypeColor(campaign.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${campaign.type.name.toUpperCase()} • ${campaign.targetSegment.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    campaign.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats Row
            Row(
              children: [
                _buildStat(Icons.people, '${campaign.totalRecipients}', isDark),
                const SizedBox(width: 16),
                _buildStat(
                  Icons.check_circle_outline,
                  '${campaign.sentCount}',
                  isDark,
                ),
                const SizedBox(width: 16),
                _buildStat(
                  Icons.error_outline,
                  '${campaign.failedCount}',
                  isDark,
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(campaign.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.grey),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No campaigns yet',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first WhatsApp campaign',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(CampaignStatus status) {
    switch (status) {
      case CampaignStatus.draft:
        return Colors.grey;
      case CampaignStatus.scheduled:
        return Colors.blue;
      case CampaignStatus.running:
        return Colors.green;
      case CampaignStatus.completed:
        return Colors.purple;
      case CampaignStatus.cancelled:
        return Colors.orange;
      case CampaignStatus.failed:
        return Colors.red;
    }
  }

  Color _getTypeColor(CampaignType type) {
    switch (type) {
      case CampaignType.whatsapp:
        return const Color(0xFF25D366);
      case CampaignType.sms:
        return Colors.blue;
      case CampaignType.both:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(CampaignType type) {
    switch (type) {
      case CampaignType.whatsapp:
        return Icons.chat;
      case CampaignType.sms:
        return Icons.sms;
      case CampaignType.both:
        return Icons.message;
    }
  }
}
