/// BoundedListController — Bounded repository queries with continuation pagination.
///
/// Wraps repository queries with configurable page size limits, prevents
/// unbounded fetches, and supports opaque continuation token pagination
/// as defined by the backend design.
///
/// Requirements: 6.14–6.17, 11.10
library;

import 'package:flutter/foundation.dart';

import '../../config/bounds_config.dart';
import '../../../mobile_shop/screens/reports/report_screen_base.dart';

/// Result of a bounded paginated query.
@immutable
class BoundedPage<T> {
  /// The items returned for this page.
  final List<T> items;

  /// Opaque continuation token for the next page, null if no more pages.
  final String? continuationToken;

  /// Whether more pages are available.
  bool get hasMore => continuationToken != null;

  const BoundedPage({required this.items, this.continuationToken});

  /// Empty page with no continuation.
  const BoundedPage.empty() : items = const [], continuationToken = null;
}

/// Fetcher function signature for paginated queries.
/// Receives the page size limit and optional continuation token.
typedef BoundedFetcher<T> =
    Future<BoundedPage<T>> Function(int limit, String? continuationToken);

/// Controls bounded list fetching with configurable limits and pagination.
///
/// Prevents unbounded fetches by enforcing [kReportDefaultLimit] as the
/// default page size and [kReportMaxLimit] as the absolute ceiling.
/// Supports continuation-token based pagination for traversing large
/// result sets without offset drift.
class BoundedListController<T> extends ChangeNotifier {
  /// The fetcher function that executes bounded queries.
  final BoundedFetcher<T> fetcher;

  /// Page size per request. Clamped to [1, kReportMaxLimit].
  final int pageSize;

  /// All items loaded so far across pages.
  List<T> _items = [];

  /// Current continuation token for the next page.
  String? _continuationToken;

  /// Whether a fetch is currently in progress.
  bool _isLoading = false;

  /// Whether more pages are available.
  bool _hasMore = true;

  /// Last error encountered during fetch.
  Object? _lastError;

  BoundedListController({required this.fetcher, int? pageSize})
    : pageSize = (pageSize ?? kReportDefaultLimit).clamp(1, kReportMaxLimit);

  /// All items loaded across all pages.
  List<T> get items => List.unmodifiable(_items);

  /// Whether a fetch is in progress.
  bool get isLoading => _isLoading;

  /// Whether more pages can be loaded.
  bool get hasMore => _hasMore;

  /// The last error, or null.
  Object? get lastError => _lastError;

  /// Whether the list is empty and not loading.
  bool get isEmpty => _items.isEmpty && !_isLoading;

  /// Current continuation token (opaque, for diagnostics only).
  String? get currentToken => _continuationToken;

  /// Load the first page, resetting any previous state.
  Future<void> loadInitial() async {
    _items = [];
    _continuationToken = null;
    _hasMore = true;
    _lastError = null;
    notifyListeners();
    await _fetchPage(null);
  }

  /// Load the next page using the current continuation token.
  /// No-op if already loading or no more pages exist.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await _fetchPage(_continuationToken);
  }

  /// Refresh: reload from the beginning while preserving item count.
  Future<void> refresh() async {
    await loadInitial();
  }

  Future<void> _fetchPage(String? token) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final page = await fetcher(pageSize, token);
      _items = token == null ? page.items : [..._items, ...page.items];
      _continuationToken = page.continuationToken;
      _hasMore = page.hasMore;
    } catch (e) {
      _lastError = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _items = [];
    super.dispose();
  }
}
