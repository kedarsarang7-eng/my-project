/// MobileShop Performance Infrastructure
///
/// Reusable controllers and widgets for bounded, debounced, latest-query-wins
/// list behavior across all mobile shop screens.
///
/// Components:
/// - [DebouncedSearchController] — Debounces text input, cancels stale queries
/// - [BoundedListController] — Bounded repository queries with pagination
/// - [StableKeyListView] — Stable-key ListView preventing rebuild churn
/// - [FilterStateController] — Change-detecting filter state management
/// - [LatestQueryGuard] — Race-condition guard for async query results
///
/// Requirements: 6.14–6.17, 11.9–11.11
library;

export 'bounded_list_controller.dart';
export 'debounced_search_controller.dart';
export 'filter_state_controller.dart';
export 'latest_query_guard.dart';
export 'stable_key_list_view.dart';
