// Gold Rate Alert Screen - Configure and Monitor Rate Alerts
// Feature 1: Gold Rate Alert System - Full Implementation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/models/gold_rate_alert_model.dart';
import '../../data/repositories/gold_rate_alert_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class GoldRateAlertScreen extends StatefulWidget {
  const GoldRateAlertScreen({super.key});

  @override
  State<GoldRateAlertScreen> createState() => _GoldRateAlertScreenState();
}

class _GoldRateAlertScreenState extends State<GoldRateAlertScreen> {
  final GoldRateAlertRepository _repository = GoldRateAlertRepository(
    sl(),
    sl<SessionManager>(),
    sl(), // NotificationService
  );

  List<GoldRateAlert> _alerts = [];
  AlertStatistics? _statistics;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  // Create alert form state
  final _thresholdController = TextEditingController();
  final _noteController = TextEditingController();
  MetalType _selectedMetalType = MetalType.gold22k;
  AlertDirection _selectedDirection = AlertDirection.above;
  NotificationMethod _selectedMethod = NotificationMethod.push;
  bool _isRecurring = false;
  int? _recurrenceHours;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Start monitoring alerts in background
    _repository.startMonitoring(interval: const Duration(minutes: 5));
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _noteController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();

      final alerts = await _repository.getAlerts(includeExpired: false);
      final stats = await _repository.getStatistics();

      setState(() {
        _alerts = alerts;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load alerts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createAlert() async {
    final threshold = double.tryParse(_thresholdController.text);
    if (threshold == null || threshold <= 0) {
      _showError('Please enter a valid threshold rate');
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _repository.createAlert(
        CreateGoldRateAlertRequest(
          metalType: _selectedMetalType,
          thresholdRatePerGram: threshold,
          direction: _selectedDirection,
          method: _selectedMethod,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
          isRecurring: _isRecurring,
          recurrenceHours: _isRecurring ? (_recurrenceHours ?? 24) : null,
        ),
      );

      // Reload data
      await _loadData();

      // Clear form
      _thresholdController.clear();
      _noteController.clear();
      setState(() {
        _isRecurring = false;
        _recurrenceHours = null;
      });

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to create alert: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _toggleAlertStatus(GoldRateAlert alert) async {
    try {
      await _repository.toggleAlertStatus(alert.id);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alert.status == AlertStatus.active
                  ? 'Alert paused'
                  : 'Alert activated',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to toggle alert: $e');
    }
  }

  Future<void> _deleteAlert(GoldRateAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert'),
        content: Text(
          'Are you sure you want to delete the alert for ${alert.metalType.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteAlert(alert.id);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alert deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to delete alert: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showCreateAlertSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCreateAlertSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : _buildMainContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAlertSheet,
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text('NEW ALERT', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildStatisticsCards()),
        if (_alerts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Active Alerts',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= _alerts.length) return null;
            return _buildAlertCard(_alerts[index]);
          }, childCount: _alerts.length),
        ),
        if (_alerts.isEmpty) SliverToBoxAdapter(child: _buildEmptyState()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFD4AF37).withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gold Rate Alerts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'MONITORING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get notified when gold rates cross your thresholds',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    if (_statistics == null) return const SizedBox.shrink();

    final isMobile = context.isMobile;

    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 12, tablet: 16, desktop: 16),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        _statistics!.activeAlerts.toString(),
                        Icons.notifications_active,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Triggered',
                        _statistics!.triggeredAlerts.toString(),
                        Icons.notifications,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'Total',
                  _statistics!.totalAlerts.toString(),
                  Icons.analytics,
                  Colors.blue,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active',
                    _statistics!.activeAlerts.toString(),
                    Icons.notifications_active,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Triggered',
                    _statistics!.triggeredAlerts.toString(),
                    Icons.notifications,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _statistics!.totalAlerts.toString(),
                    Icons.analytics,
                    Colors.blue,
                  ),
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
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(GoldRateAlert alert) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = alert.status.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getMetalColor(alert.metalType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getMetalColor(alert.metalType).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    alert.metalType.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getMetalColor(alert.metalType),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'toggle') {
                      _toggleAlertStatus(alert);
                    } else if (value == 'delete') {
                      _deleteAlert(alert);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            alert.status == AlertStatus.active
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            alert.status == AlertStatus.active
                                ? 'Pause'
                                : 'Activate',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAlertDetail(
                    'Threshold',
                    '₹${alert.displayThreshold.toStringAsFixed(2)}/g',
                    Icons.flag,
                  ),
                ),
                Expanded(
                  child: _buildAlertDetail(
                    'Direction',
                    alert.direction.displayName,
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildAlertDetail(
                    'Notify via',
                    alert.method.displayName,
                    alert.method.icon,
                  ),
                ),
              ],
            ),
            if (alert.note != null) ...[
              const SizedBox(height: 12),
              Text(
                alert.note!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (alert.lastTriggeredAt != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    'Last triggered: ${DateFormat('MMM d, h:mm a').format(alert.lastTriggeredAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (alert.triggerCount > 0) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${alert.triggerCount} times',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertDetail(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getMetalColor(MetalType type) {
    switch (type) {
      case MetalType.gold24k:
        return const Color(0xFFFFD700);
      case MetalType.gold22k:
        return const Color(0xFFFFE55C);
      case MetalType.gold18k:
        return const Color(0xFFE6C200);
      case MetalType.silver:
        return Colors.grey;
      case MetalType.platinum:
        return const Color(0xFFE5E4E2);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No alerts yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first gold rate alert to get notified',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAlertSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_alert, color: Color(0xFFD4AF37)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create Gold Rate Alert',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Metal Type Selection
            Text(
              'Metal Type',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  [
                    MetalType.gold24k,
                    MetalType.gold22k,
                    MetalType.gold18k,
                    MetalType.silver,
                    MetalType.platinum,
                  ].map((type) {
                    final isSelected = _selectedMetalType == type;
                    return ChoiceChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedMetalType = type);
                      },
                      selectedColor: _getMetalColor(type).withOpacity(0.2),
                      side: BorderSide(
                        color: isSelected
                            ? _getMetalColor(type)
                            : Colors.grey[300]!,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),

            // Threshold Rate
            TextField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Alert when rate is',
                hintText: 'Enter rate per gram',
                prefixIcon: const Icon(Icons.currency_rupee),
                suffixText: '/g',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Direction
            Text(
              'Alert Direction',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Column(
              children: AlertDirection.values.map((direction) {
                return RadioListTile<AlertDirection>(
                  title: Text(direction.displayName),
                  subtitle: Text(
                    direction.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: direction,
                  groupValue: _selectedDirection,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDirection = value);
                    }
                  },
                  dense: true,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Notification Method
            Text(
              'Notify me via',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: NotificationMethod.values.map((method) {
                final isSelected = _selectedMethod == method;
                return ChoiceChip(
                  avatar: Icon(method.icon, size: 18),
                  label: Text(method.displayName),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedMethod = method);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Recurring Alert
            CheckboxListTile(
              title: const Text('Recurring Alert'),
              subtitle: const Text(
                'Reset and notify again after specified hours',
                style: TextStyle(fontSize: 12),
              ),
              value: _isRecurring,
              onChanged: (value) {
                setState(() => _isRecurring = value ?? false);
              },
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Repeat after (hours)',
                  hintText: '24',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  _recurrenceHours = int.tryParse(value);
                },
              ),
            ],
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Why are you setting this alert?',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'CREATE ALERT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
