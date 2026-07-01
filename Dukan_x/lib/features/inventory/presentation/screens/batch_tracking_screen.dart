import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/database/app_database.dart'; // For ProductBatchEntity
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../utils/batch_pagination.dart';

/// Batch Tracking Screen
///
/// Manages product batches (expiry, manufacturing, stock).
/// Critical for Pharmacy (FMCG) compliance.
class BatchTrackingScreen extends ConsumerStatefulWidget {
  const BatchTrackingScreen({super.key});

  @override
  ConsumerState<BatchTrackingScreen> createState() =>
      _BatchTrackingScreenState();
}

class _BatchTrackingScreenState extends ConsumerState<BatchTrackingScreen> {
  // Fixed page size for screen-level pagination. Sourced from the shared
  // inventory pagination helper so the [20, 50] bound (Requirement 20.1) is
  // defined and verified in one place.
  static const int _pageSize = kBatchTrackingPageSize;

  // Trigger loading the next segment when the user scrolls within this many
  // records of the end of the currently displayed list (Requirement 20.2).
  static const int _loadMoreThreshold = 5;

  bool _loading = true; // Initial / full reload in progress.
  bool _loadingMore = false; // Next-segment load in progress.
  String? _errorMessage; // Non-null when the last load failed (R20.4).

  // Full dataset retrieved from the repository. Retained across failed reloads
  // so previously loaded records are never discarded (R20.5).
  List<ProductBatchEntity> _allBatches = [];
  Map<String, String> _productNames = {};

  // Number of filtered records currently revealed. Grows one page at a time.
  int _visibleCount = _pageSize;

  String _searchQuery = '';
  bool _showExpiredOnly = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Could not load batch data: no active user session. Please retry.';
      });
      return;
    }

    try {
      final repo = sl<ProductsRepository>();

      // Load all active batches.
      final result = await repo.getAllBatches(userId);
      final batches = result.data ?? [];

      // Load products to map IDs to Names.
      final productsResult = await repo.getAll(userId: userId);
      final products = productsResult.data ?? [];

      setState(() {
        _allBatches = batches;
        _productNames = {for (var p in products) p.id: p.name};
        _resetPagination();
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      // Fail visible, not silent: keep any previously loaded records (R20.5)
      // and surface an error state with a retry control (R20.4, R20.6).
      setState(() {
        _loading = false;
        _errorMessage =
            'Could not load batch data. Check your connection and retry.';
      });
    }
  }

  /// Resets the revealed window to the first page. Called after a successful
  /// load and whenever the active filter/search changes.
  void _resetPagination() {
    _visibleCount = _pageSize;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingMore || _loading) return;
    if (!_hasMore) return;

    final position = _scrollController.position;
    // Approximate "within N records of the end" using the average row extent.
    final visibleBatches = _visibleBatches;
    if (visibleBatches.isEmpty) return;
    final avgExtent = position.maxScrollExtent / visibleBatches.length;
    final thresholdPixels =
        position.maxScrollExtent - (avgExtent * _loadMoreThreshold);

    if (position.pixels >= thresholdPixels) {
      _loadNextSegment();
    }
  }

  /// Reveals the next bounded segment of the filtered dataset (R20.2, R20.3).
  Future<void> _loadNextSegment() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    // Yield a frame so the loading indicator is visible during the segment
    // load, then expand the revealed window by one fixed page.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;

    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(
        0,
        _filteredBatches.length,
      );
      _loadingMore = false;
    });
  }

  /// Full filtered dataset (search + expired toggle applied).
  List<ProductBatchEntity> get _filteredBatches {
    final now = DateTime.now();
    return _allBatches.where((batch) {
      final productName = _productNames[batch.productId] ?? '';
      final matchesSearch =
          batch.batchNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          productName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_showExpiredOnly) {
        return matchesSearch &&
            batch.expiryDate != null &&
            batch.expiryDate!.isBefore(now);
      }
      return matchesSearch;
    }).toList();
  }

  /// The bounded window of filtered records currently displayed.
  List<ProductBatchEntity> get _visibleBatches {
    final filtered = _filteredBatches;
    final count = _visibleCount.clamp(0, filtered.length);
    return filtered.sublist(0, count);
  }

  /// Whether more filtered records remain beyond the revealed window.
  bool get _hasMore => batchHasMore(_filteredBatches.length, _visibleCount);

  /// Updates the active filter/search and rewinds pagination to page one.
  void _applyFilter(VoidCallback mutate) {
    setState(() {
      mutate();
      _resetPagination();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Batch Tracking',
      subtitle: '${_filteredBatches.length} active batches',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          // Filters & Search
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            _applyFilter(() => _searchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search batch number or product...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilterChip(
                      label: const Text('Expired Only'),
                      selected: _showExpiredOnly,
                      onSelected: (val) =>
                          _applyFilter(() => _showExpiredOnly = val),
                      backgroundColor: isDark
                          ? Colors.black26
                          : Colors.grey[100],
                      selectedColor: const Color(0xFFEF4444).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _showExpiredOnly
                            ? const Color(0xFFEF4444)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(child: _buildValues(isDark)),
        ],
      ),
    );
  }

  // Header removed as moved to body/container props

  Widget _buildValues(bool isDark) {
    // Initial / full reload in progress: single loading indicator (R20.3).
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Load failed: surface a visible error state with a retry control instead
    // of an empty list (R20.4, R20.6). Previously loaded records are retained
    // (R20.5): when data is still present, keep the list and show a dismissible
    // error banner above it; otherwise show a full-screen error state.
    if (_errorMessage != null) {
      if (_filteredBatches.isEmpty) {
        return _buildErrorState(isDark, _errorMessage!);
      }
      return Column(
        children: [
          _buildErrorBanner(isDark, _errorMessage!),
          Expanded(child: _buildList(isDark)),
        ],
      );
    }

    // Successful load returning zero records: distinct empty state (R20.7).
    if (_filteredBatches.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return _buildList(isDark);
  }

  /// Scrollable list of the bounded window of revealed records. Appends a
  /// trailing loading indicator while the next segment loads (R20.2, R20.3).
  Widget _buildList(bool isDark) {
    final visible = _visibleBatches;
    final showLoadMore = _hasMore || _loadingMore;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: visible.length + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildBatchCard(visible[index], isDark);
      },
    );
  }

  /// Distinct empty-state shown when a successful load returns zero records
  /// (R20.7). Visually separate from the error state below.
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No batches found',
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
              ),
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen error state with message + retry control (R20.4). Retry
  /// reattempts the failed load (R20.6).
  Widget _buildErrorState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 14.0,
                  tablet: 16.0,
                  desktop: 16.0,
                ),
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Compact error banner shown above retained records when a reload fails
  /// (R20.4, R20.5). The retry control reattempts the failed load (R20.6).
  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBatchCard(ProductBatchEntity batch, bool isDark) {
    final productName = _productNames[batch.productId] ?? 'Unknown Product';
    final isExpired =
        batch.expiryDate != null && batch.expiryDate!.isBefore(DateTime.now());
    final expiryColor = isExpired
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isExpired
                    ? const Color(0xFFEF4444).withOpacity(0.1)
                    : const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isExpired ? Icons.event_busy : Icons.qr_code,
                color: isExpired
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF8B5CF6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          batch.batchNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Monospace',
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Qty: ${batch.stockQuantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: expiryColor),
                      const SizedBox(width: 4),
                      Text(
                        batch.expiryDate != null
                            ? 'Expires: ${DateFormat('dd MMM yyyy').format(batch.expiryDate!)}'
                            : 'No Expiry',
                        style: TextStyle(
                          fontSize: 12,
                          color: expiryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MRP: ₹${batch.mrp.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
