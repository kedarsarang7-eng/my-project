import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../services/websocket_service.dart';
import '../../data/models/food_order_model.dart';
import '../../data/repositories/food_order_repository.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantOwnerCommandScreen extends StatefulWidget {
  const RestaurantOwnerCommandScreen({super.key});

  @override
  State<RestaurantOwnerCommandScreen> createState() =>
      _RestaurantOwnerCommandScreenState();
}

class _RestaurantOwnerCommandScreenState
    extends State<RestaurantOwnerCommandScreen> {
  static const String _recentExportsKeyPrefix = 'restaurant_recent_exports_v1';
  final FoodOrderRepository _orderRepository = FoodOrderRepository();
  final RestaurantOpsRepository _opsRepository = RestaurantOpsRepository();
  final Map<String, _StaffPresence> _staffPresence = {};

  bool _loading = true;
  String _vendorId = '';
  int _wsRefreshCount = 0;
  DateTime? _lastLoadedAt;

  List<FoodOrder> _liveOrders = const [];
  List<Map<String, dynamic>> _aggregatorOrders = const [];
  double _todayRevenue = 0;
  int _todayOrders = 0;

  bool _exportingOrders = false;
  bool _exportingGst = false;
  bool _exportingStaff = false;
  final List<_ExportHistoryItem> _recentExports = [];

  @override
  void initState() {
    super.initState();
    final session = sl<SessionManager>();
    _vendorId =
        session.currentSession.activeBusinessId ??
        session.ownerId ??
        session.userId ??
        '';
    unawaited(_loadRecentExports());
    _bindRealtime();
    _loadAll();
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(WSEventName.orderCreated, _onOrderWs);
    WebSocketService.instance.unsubscribe(WSEventName.orderUpdated, _onOrderWs);
    WebSocketService.instance.unsubscribe(WSEventName.billUpdated, _onOrderWs);
    WebSocketService.instance.unsubscribe(
      WSEventName.paymentSuccess,
      _onOrderWs,
    );
    WebSocketService.instance.unsubscribe(
      WSEventName.staffLogin,
      _onStaffLogin,
    );
    WebSocketService.instance.unsubscribe(
      WSEventName.staffLogout,
      _onStaffLogout,
    );
    WebSocketService.instance.unsubscribe(
      WSEventName.staffActivity,
      _onStaffActivity,
    );
    super.dispose();
  }

  void _bindRealtime() {
    WebSocketService.instance.subscribe(WSEventName.orderCreated, _onOrderWs);
    WebSocketService.instance.subscribe(WSEventName.orderUpdated, _onOrderWs);
    WebSocketService.instance.subscribe(WSEventName.billUpdated, _onOrderWs);
    WebSocketService.instance.subscribe(
      WSEventName.paymentSuccess,
      _onOrderWs,
    );
    WebSocketService.instance.subscribe(WSEventName.staffLogin, _onStaffLogin);
    WebSocketService.instance.subscribe(
      WSEventName.staffLogout,
      _onStaffLogout,
    );
    WebSocketService.instance.subscribe(
      WSEventName.staffActivity,
      _onStaffActivity,
    );
  }

  Future<void> _loadAll() async {
    if (_vendorId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final pendingResult = await _orderRepository.getPendingOrders(_vendorId);
    final aggregatorOrders = await _opsRepository.listAggregatorOrders();
    final todayRevenue = await _orderRepository.getTodayRevenue(_vendorId);
    final todayOrders = await _orderRepository.getTodayOrderCount(_vendorId);

    if (!mounted) return;
    setState(() {
      _liveOrders = pendingResult.data ?? const [];
      _aggregatorOrders = aggregatorOrders;
      _todayRevenue = todayRevenue;
      _todayOrders = todayOrders;
      _lastLoadedAt = DateTime.now();
      _loading = false;
    });
  }

  void _onOrderWs(WSEvent event) {
    if (!mounted) return;
    setState(() {
      _wsRefreshCount += 1;
    });
    unawaited(_loadAll());
  }

  void _onStaffLogin(WSEvent event) {
    _upsertStaffFromEvent(event, online: true);
  }

  void _onStaffLogout(WSEvent event) {
    _upsertStaffFromEvent(event, online: false);
  }

  void _onStaffActivity(WSEvent event) {
    _upsertStaffFromEvent(event, online: true);
  }

  void _upsertStaffFromEvent(WSEvent event, {required bool online}) {
    final rawId =
        event.data['staffId'] ??
        event.data['userId'] ??
        event.data['id'] ??
        'unknown';
    final id = rawId.toString();
    final rawName = event.data['staffName'] ?? event.data['name'] ?? id;
    final name = rawName.toString();

    if (!mounted) return;
    setState(() {
      _staffPresence[id] = _StaffPresence(
        id: id,
        name: name,
        online: online,
        lastSeen: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final onlineStaff = _staffPresence.values.where((e) => e.online).toList();
    final gstEstimate = _todayRevenue * 0.05;
    final netAfterGst =
        (_todayRevenue - gstEstimate).clamp(0, double.infinity).toDouble();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final hasVendor = _vendorId.isNotEmpty;
    final commandStatus = hasVendor
        ? 'Connected to $_vendorId'
        : 'Business context missing';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 14,
                  vertical: 16,
                ),
                children: [
                  _buildHeroHeader(commandStatus),
                  const SizedBox(height: 16),
                  _buildTopKpis(
                    gstEstimate: gstEstimate,
                    netAfterGst: netAfterGst,
                    onlineStaff: onlineStaff.length,
                  ),
                  const SizedBox(height: 12),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildOrderFeedCard(isDesktop: isDesktop),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStaffCard(onlineStaff)),
                      ],
                    )
                  else ...[
                    _buildOrderFeedCard(isDesktop: isDesktop),
                    const SizedBox(height: 12),
                    _buildStaffCard(onlineStaff),
                  ],
                  const SizedBox(height: 12),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildFinanceCard(
                            todayRevenue: _todayRevenue,
                            gstEstimate: gstEstimate,
                            netAfterGst: netAfterGst,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExportCard()),
                      ],
                    )
                  else ...[
                    _buildFinanceCard(
                      todayRevenue: _todayRevenue,
                      gstEstimate: gstEstimate,
                      netAfterGst: netAfterGst,
                    ),
                    const SizedBox(height: 12),
                    _buildExportCard(),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadAll,
        icon: const Icon(Icons.sync),
        label: const Text('Sync'),
      ),
    );
  }

  Widget _buildHeroHeader(String commandStatus) {
    final lastSyncLabel = _lastLoadedAt == null
        ? 'Never'
        : '${_lastLoadedAt!.hour.toString().padLeft(2, '0')}:${_lastLoadedAt!.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 24,
            spreadRadius: 1,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restaurant Owner Command Center',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            commandStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip('WS events: $_wsRefreshCount'),
              _headerChip('Last sync: $lastSyncLabel'),
              _headerChip('Aggregator: ${_aggregatorOrders.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTopKpis({
    required double gstEstimate,
    required double netAfterGst,
    required int onlineStaff,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final data = [
          _KpiData(
            label: 'Today Orders',
            value: '$_todayOrders',
            icon: Icons.receipt_long_outlined,
            tone: const Color(0xFF2563EB),
          ),
          _KpiData(
            label: 'Gross Revenue',
            value: '₹${_todayRevenue.toStringAsFixed(0)}',
            icon: Icons.trending_up_outlined,
            tone: const Color(0xFF16A34A),
          ),
          _KpiData(
            label: 'GST Estimate',
            value: '₹${gstEstimate.toStringAsFixed(0)}',
            icon: Icons.account_balance_outlined,
            tone: const Color(0xFFF59E0B),
          ),
          _KpiData(
            label: 'Online Staff',
            value: '$onlineStaff',
            icon: Icons.groups_2_outlined,
            tone: const Color(0xFF7C3AED),
          ),
          _KpiData(
            label: 'Net After GST',
            value: '₹${netAfterGst.toStringAsFixed(0)}',
            icon: Icons.payments_outlined,
            tone: const Color(0xFF0EA5E9),
          ),
        ];

        return GridView.builder(
          itemCount: data.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 5 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isWide ? 1.8 : 1.7,
          ),
          itemBuilder: (context, index) => _KpiTile(item: data[index]),
        );
      },
    );
  }

  Widget _buildOrderFeedCard({required bool isDesktop}) {
    return _sectionCard(
      context,
      title: 'Live Order Feed',
      subtitle:
          '${_liveOrders.length} active local orders • ${_aggregatorOrders.length} aggregator',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: isDesktop ? 440 : 360),
        child: ListView.separated(
          itemCount: _liveOrders.isEmpty ? 1 : _liveOrders.length.clamp(0, 12),
          separatorBuilder: (_, _) => const Divider(height: 14),
          itemBuilder: (context, index) {
            if (_liveOrders.isEmpty) {
              return const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('No active local orders'),
                subtitle: Text('Feed updates in realtime on new events.'),
              );
            }
            final o = _liveOrders[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: _statusTone(o.orderStatus).withValues(alpha: 0.14),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: _statusTone(o.orderStatus),
                ),
              ),
              title: Text(
                'Order ${o.id.substring(0, o.id.length > 8 ? 8 : o.id.length)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${o.orderStatus.displayName} • Table ${o.tableNumber ?? '-'} • ${o.itemCount} items',
              ),
              trailing: Text(
                '₹${o.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStaffCard(List<_StaffPresence> onlineStaff) {
    return _sectionCard(
      context,
      title: 'Staff Online Status',
      subtitle:
          '${onlineStaff.length} online • ${_staffPresence.length} seen in session',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onlineStaff.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: onlineStaff
                  .take(18)
                  .map(
                    (s) => Chip(
                      side: BorderSide.none,
                      avatar: const Icon(
                        Icons.circle,
                        size: 10,
                        color: Color(0xFF16A34A),
                      ),
                      label: Text(s.name),
                    ),
                  )
                  .toList(),
            )
          else
            const Text('No online staff event yet. Waiting for login activity.'),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Text(
            'Recent presence updates',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ..._staffPresence.values
              .toList()
              .reversed
              .take(4)
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        s.online ? Icons.circle : Icons.circle_outlined,
                        size: 11,
                        color: s.online
                            ? const Color(0xFF16A34A)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.name)),
                      Text(
                        '${s.lastSeen.hour.toString().padLeft(2, '0')}:${s.lastSeen.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard({
    required double todayRevenue,
    required double gstEstimate,
    required double netAfterGst,
  }) {
    return _sectionCard(
      context,
      title: 'GST & Finance Baseline',
      subtitle: 'Daily baseline for owner finance review',
      child: Column(
        children: [
          _metricRow('Today Orders', '$_todayOrders'),
          _metricRow('Gross Revenue', '₹${todayRevenue.toStringAsFixed(2)}'),
          _metricRow('Estimated GST (5%)', '₹${gstEstimate.toStringAsFixed(2)}'),
          _metricRow('Net Revenue', '₹${netAfterGst.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return _sectionCard(
      context,
      title: 'Settings & Export Hooks',
      subtitle: 'Connected to repository export hooks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _exportingOrders ? null : _exportOrders,
                icon: _exportingOrders
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Export Orders CSV'),
              ),
              FilledButton.tonalIcon(
                onPressed: _exportingGst ? null : _exportGstSummary,
                icon: _exportingGst
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: const Text('Export GST Summary'),
              ),
              OutlinedButton.icon(
                onPressed: _exportingStaff ? null : _exportStaffSessionLog,
                icon: _exportingStaff
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.people_alt_outlined),
                label: const Text('Export Staff Session Log'),
              ),
              OutlinedButton.icon(
                onPressed: _openDefaultExportFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open Export Folder'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Exports',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _recentExports.isEmpty ? null : _clearRecentExports,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear History'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_recentExports.isEmpty)
            Text(
              'No recent exports.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ..._recentExports.map(_buildRecentExportTile),
        ],
      ),
    );
  }

  Widget _buildRecentExportTile(_ExportHistoryItem item) {
    final hh = item.createdAt.hour.toString().padLeft(2, '0');
    final mm = item.createdAt.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$hh:$mm • ${item.filePath}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy path',
            onPressed: () => _copyPathToClipboard(item.filePath),
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeRecentExport(item),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
          IconButton(
            tooltip: 'Open folder',
            onPressed: () => _openFolder(item.folderPath),
            icon: const Icon(Icons.folder_open, size: 18),
          ),
          IconButton(
            tooltip: 'Open file',
            onPressed: () => _openFile(item.filePath),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOrders() async {
    setState(() => _exportingOrders = true);
    final result = await _opsRepository.requestRestoExportDetailed(
      report: 'orders',
      format: 'csv',
    );
    if (!mounted) return;
    setState(() => _exportingOrders = false);
    await _handleExportResult(result, successLabel: 'Order export saved');
  }

  Future<void> _exportGstSummary() async {
    setState(() => _exportingGst = true);
    final result = await _opsRepository.requestRestoExportDetailed(
      report: 'gst_summary',
      format: 'csv',
    );
    if (!mounted) return;
    setState(() => _exportingGst = false);
    await _handleExportResult(result, successLabel: 'GST summary export saved');
  }

  Future<void> _exportStaffSessionLog() async {
    setState(() => _exportingStaff = true);
    final result = await _opsRepository.requestRestoExportDetailed(
      report: 'staff_session_log',
      format: 'csv',
    );
    if (!mounted) return;
    setState(() => _exportingStaff = false);
    await _handleExportResult(result, successLabel: 'Staff session export saved');
  }

  Future<void> _handleExportResult(
    RestoExportResult result, {
    required String successLabel,
  }) async {
    if (!result.success) {
      _showExportMessage(
        result.error ?? 'Export failed. Verify backend export route.',
        ok: false,
      );
      return;
    }

    final csv = result.csv ?? '';
    if (csv.trim().isEmpty) {
      _showExportMessage(
        'Export API responded without CSV body.',
        ok: false,
      );
      return;
    }

    final filePath = await _saveCsvToLocal(
      fileName: result.fileName ?? 'resto_export.csv',
      csv: csv,
    );
    if (!mounted) return;
    _trackRecentExport(successLabel: successLabel, filePath: filePath);
    _showExportSuccessDialog(successLabel: successLabel, filePath: filePath);
  }

  void _trackRecentExport({
    required String successLabel,
    required String filePath,
  }) {
    final file = File(filePath);
    final next = _ExportHistoryItem(
      label: successLabel,
      filePath: filePath,
      folderPath: file.parent.path,
      createdAt: DateTime.now(),
    );
    setState(() {
      _recentExports.removeWhere((item) => item.filePath == next.filePath);
      _recentExports.insert(0, next);
      if (_recentExports.length > 5) {
        _recentExports.removeRange(5, _recentExports.length);
      }
    });
    unawaited(_persistRecentExports());
  }

  String _recentExportsKey() {
    final scope = _vendorId.trim().isEmpty ? 'global' : _vendorId.trim();
    return '$_recentExportsKeyPrefix:$scope';
  }

  Future<void> _loadRecentExports() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_recentExportsKey());
    if (encoded == null || encoded.trim().isEmpty) return;
    try {
      final raw = jsonDecode(encoded);
      if (raw is! List) return;
      final entries = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(_ExportHistoryItem.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _recentExports
          ..clear()
          ..addAll(entries.take(5));
      });
    } catch (_) {
      // Ignore malformed persisted payload and continue with empty history.
    }
  }

  Future<void> _persistRecentExports() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _recentExports.take(5).map((e) => e.toJson()).toList();
    await prefs.setString(_recentExportsKey(), jsonEncode(payload));
  }

  Future<void> _clearRecentExports() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Recent Exports?'),
          content: const Text(
            'This clears all recent export entries for current business scope.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (shouldClear != true) return;

    setState(() {
      _recentExports.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentExportsKey());
    if (!mounted) return;
    _showExportMessage('Recent export history cleared.', ok: true);
  }

  Future<void> _removeRecentExport(_ExportHistoryItem item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Export Entry?'),
          content: Text(
            'This removes entry from recent history only.\n\n${item.filePath}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true) return;

    setState(() {
      _recentExports.removeWhere(
        (entry) =>
            entry.filePath == item.filePath &&
            entry.createdAt.isAtSameMomentAs(item.createdAt),
      );
    });
    await _persistRecentExports();
    if (!mounted) return;
    _showExportMessage('Removed from recent exports.', ok: true);
  }

  Future<String> _saveCsvToLocal({
    required String fileName,
    required String csv,
  }) async {
    final exportDir = await _resolveExportDir();
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final safeName = fileName.trim().isEmpty ? 'resto_export.csv' : fileName;
    final file = File('${exportDir.path}\\$safeName');
    await file.writeAsString(csv);
    return file.path;
  }

  Future<Directory> _resolveExportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}\\exports\\resto');
  }

  Future<void> _openDefaultExportFolder() async {
    try {
      final exportDir = await _resolveExportDir();
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      await _openFolder(exportDir.path);
    } catch (e) {
      if (!mounted) return;
      _showExportMessage('Could not open export folder: $e', ok: false);
    }
  }

  void _showExportMessage(String message, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? const Color(0xFF166534) : const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showExportSuccessDialog({
    required String successLabel,
    required String filePath,
  }) async {
    final folderPath = File(filePath).parent.path;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Export Complete'),
          content: Text('$successLabel\n\n$filePath'),
          actions: [
            TextButton(
              onPressed: () => _copyPathToClipboard(filePath),
              child: const Text('Copy Path'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openFolder(folderPath);
              },
              child: const Text('Open Folder'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openFile(filePath);
              },
              child: const Text('Open File'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else {
        throw UnsupportedError('Platform not supported for opening folder');
      }
    } catch (e) {
      if (!mounted) return;
      _showExportMessage('Could not open folder: $e', ok: false);
    }
  }

  Future<void> _copyPathToClipboard(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    _showExportMessage('Path copied to clipboard.', ok: true);
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else {
        throw UnsupportedError('Platform not supported for opening file');
      }
    } catch (e) {
      if (!mounted) return;
      _showExportMessage('Could not open file: $e', ok: false);
    }
  }

  Color _statusTone(FoodOrderStatus status) {
    switch (status) {
      case FoodOrderStatus.pending:
        return const Color(0xFFF59E0B);
      case FoodOrderStatus.accepted:
        return const Color(0xFF2563EB);
      case FoodOrderStatus.cooking:
        return const Color(0xFFF97316);
      case FoodOrderStatus.ready:
        return const Color(0xFF16A34A);
      case FoodOrderStatus.served:
      case FoodOrderStatus.completed:
        return const Color(0xFF0EA5E9);
      case FoodOrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });
}

class _KpiTile extends StatelessWidget {
  final _KpiData item;

  const _KpiTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.tone, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w800,
              color: item.tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPresence {
  final String id;
  final String name;
  final bool online;
  final DateTime lastSeen;

  const _StaffPresence({
    required this.id,
    required this.name,
    required this.online,
    required this.lastSeen,
  });
}

class _ExportHistoryItem {
  final String label;
  final String filePath;
  final String folderPath;
  final DateTime createdAt;

  const _ExportHistoryItem({
    required this.label,
    required this.filePath,
    required this.folderPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'filePath': filePath,
      'folderPath': folderPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static _ExportHistoryItem fromJson(Map<String, dynamic> json) {
    final label = (json['label'] ?? '').toString();
    final filePath = (json['filePath'] ?? '').toString();
    final folderPath = (json['folderPath'] ?? '').toString();
    final createdAtRaw = (json['createdAt'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    return _ExportHistoryItem(
      label: label.isEmpty ? 'Export' : label,
      filePath: filePath,
      folderPath: folderPath.isEmpty ? File(filePath).parent.path : folderPath,
      createdAt: createdAt,
    );
  }
}
