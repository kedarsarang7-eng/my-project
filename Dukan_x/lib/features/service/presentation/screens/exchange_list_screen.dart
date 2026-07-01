/// Exchange List Screen
/// Shows all device exchanges with filtering and stats overview
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../models/exchange.dart';
import '../../services/exchange_service.dart';
import 'create_exchange_screen.dart';
import 'exchange_detail_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ExchangeListScreen extends StatefulWidget {
  const ExchangeListScreen({super.key});

  @override
  State<ExchangeListScreen> createState() => _ExchangeListScreenState();
}

class _ExchangeListScreenState extends State<ExchangeListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExchangeService _exchangeService;
  String? _userId;
  bool _isLoading = true;
  String? _sessionError;
  Map<String, dynamic> _stats = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initService();
  }

  Future<void> _initService() async {
    final db = AppDatabase.instance;
    _exchangeService = ExchangeService(db);
    _userId = sl<SessionManager>().userId;

    if (_userId != null) {
      await _loadStats();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sessionError = null;
        });
      }
      return;
    }

    // Identity is null immediately — show error and start a 10-second timeout
    if (mounted) {
      setState(() {
        _isLoading = false;
        _sessionError = 'Invalid or expired session. Please log in again.';
      });
    }

    // Allow up to 10 seconds for the session to resolve
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      final retryUserId = sl<SessionManager>().userId;
      if (retryUserId != null) {
        _userId = retryUserId;
        _loadStats().then((_) {
          if (mounted) {
            setState(() {
              _sessionError = null;
            });
          }
        });
      } else if (_userId == null) {
        setState(() {
          _sessionError = 'Session could not be resolved. Please try again.';
        });
      }
    });
  }

  Future<void> _loadStats() async {
    if (_userId != null) {
      _stats = await _exchangeService.getExchangeStats(_userId!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Exchanges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Drafts'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          Semantics(
            label: 'Refresh exchange statistics',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh stats',
              onPressed: () async {
                await _loadStats();
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            _buildStatsCards(),
            _buildSearchBar(),
            Expanded(child: _buildExchangeList()),
          ],
        ),
      ),
      floatingActionButton: Semantics(
        label: 'Create new device exchange',
        child: Tooltip(
          message: 'Create new device exchange',
          child: FloatingActionButton.extended(
            onPressed: _createNewExchange,
            icon: const Icon(Icons.add),
            label: const Text('New Exchange'),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildStatCard(
            icon: Icons.swap_horiz_rounded,
            label: 'Total',
            value: '${_stats['totalExchanges'] ?? 0}',
            color: FuturisticColors.accent2,
          ),
          _buildStatCard(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: '${_stats['completedExchanges'] ?? 0}',
            color: FuturisticColors.success,
          ),
          _buildStatCard(
            icon: Icons.edit_note_rounded,
            label: 'Drafts',
            value: '${_stats['draftExchanges'] ?? 0}',
            color: FuturisticColors.warning,
          ),
          _buildStatCard(
            icon: Icons.currency_rupee_rounded,
            label: 'Value',
            value:
                '₹${((_stats['totalExchangeValue'] ?? 0) / 1000).toStringAsFixed(1)}K',
            color: FuturisticColors.accent1,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Semantics(
      label: '$label: $value',
      child: Tooltip(
        message: '$label: $value',
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: FuturisticColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by exchange #, customer, or device...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? Semantics(
                  label: 'Clear search query',
                  child: Tooltip(
                    message: 'Clear search',
                    child: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        onChanged: (value) {
          _debounceTimer?.cancel();
          if (value.isEmpty) {
            // Clear immediately so the full list shows within 300ms
            setState(() => _searchQuery = '');
          } else {
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => _searchQuery = value);
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildExchangeList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessionError != null || _userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: FuturisticColors.error.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                _sessionError ??
                    'Invalid or expired session. Please log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: FuturisticColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _sessionError = null;
                  });
                  _initService();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildExchangeStream(null),
        _buildExchangeStream(ExchangeStatus.draft),
        _buildExchangeStream(ExchangeStatus.completed),
      ],
    );
  }

  Widget _buildExchangeStream(ExchangeStatus? status) {
    return StreamBuilder<List<Exchange>>(
      stream: _exchangeService.watchExchanges(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var exchanges = snapshot.data ?? [];

        if (status != null) {
          exchanges = exchanges.where((e) => e.status == status).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          exchanges = exchanges.where((e) {
            return (e.exchangeNumber?.toLowerCase().contains(query) ?? false) ||
                e.customerName.toLowerCase().contains(query) ||
                e.oldDeviceName.toLowerCase().contains(query) ||
                e.newProductName.toLowerCase().contains(query);
          }).toList();
        }

        if (exchanges.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: exchanges.length,
          itemBuilder: (context, index) {
            return _buildExchangeCard(exchanges[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 64,
            color: FuturisticColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'No exchanges yet',
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
              ),
              fontWeight: FontWeight.w600,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create a new exchange',
            style: TextStyle(color: FuturisticColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard(Exchange exchange) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(exchange.status);

    return Semantics(
      label:
          'Exchange ${exchange.exchangeNumber ?? "draft"} for '
          '${exchange.customerName}, status: ${exchange.status.displayName}',
      child: Tooltip(
        message:
            '${exchange.exchangeNumber ?? "Draft"} – ${exchange.customerName} (${exchange.status.displayName})',
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openExchangeDetail(exchange),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exchange.exchangeNumber ?? 'Draft',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              exchange.customerName,
                              style: TextStyle(
                                color: FuturisticColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(exchange.status),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Device exchange info
                  Row(
                    children: [
                      Expanded(
                        child: _buildDeviceInfo(
                          'Old Device',
                          exchange.oldDeviceName,
                          Icons.phone_android,
                          FuturisticColors.warning,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: _buildDeviceInfo(
                          'New Device',
                          exchange.newProductName,
                          Icons.smartphone,
                          FuturisticColors.success,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Footer with prices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPriceInfo(
                        'Exchange Value',
                        '₹${exchange.exchangeValue.toStringAsFixed(0)}',
                      ),
                      _buildPriceInfo(
                        'To Pay',
                        '₹${exchange.amountToPay.toStringAsFixed(0)}',
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: FuturisticColors.textDisabled),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FuturisticColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPriceInfo(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: FuturisticColors.textDisabled),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
            ),
            fontWeight: FontWeight.bold,
            color: highlight
                ? FuturisticColors.accent2
                : FuturisticColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ExchangeStatus status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(ExchangeStatus status) {
    switch (status) {
      case ExchangeStatus.draft:
        return FuturisticColors.warning;
      case ExchangeStatus.completed:
        return FuturisticColors.success;
      case ExchangeStatus.cancelled:
        return FuturisticColors.error;
    }
  }

  void _createNewExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateExchangeScreen()),
    ).then((_) => _loadStats());
  }

  void _openExchangeDetail(Exchange exchange) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExchangeDetailScreen(exchangeId: exchange.id),
      ),
    ).then((_) => _loadStats());
  }
}
