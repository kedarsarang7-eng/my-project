/// StableKeyListView — ListView wrapper with stable keys to prevent rebuilds.
///
/// Uses stable keys for items to prevent unnecessary widget rebuilds during
/// filter changes or list updates. Supports both fixed-size and variable-size
/// items, and integrates with [BoundedListController] for load-more pagination.
///
/// Requirements: 11.10, 11.11
library;

import 'package:flutter/material.dart';

import 'bounded_list_controller.dart';

/// Extracts a stable, unique key from an item for widget identity.
typedef StableKeyExtractor<T> = String Function(T item);

/// Builds a widget for an item in the list.
typedef StableItemBuilder<T> = Widget Function(BuildContext context, T item);

/// A ListView that uses stable keys for each item, preventing unnecessary
/// rebuilds when the list is re-filtered or updated with the same items.
///
/// When items are merely reordered or a subset changes, Flutter can efficiently
/// reuse existing widgets for items whose keys haven't changed.
///
/// Optionally integrates with [BoundedListController] to trigger load-more
/// when the user scrolls near the bottom.
class StableKeyListView<T> extends StatefulWidget {
  /// The items to display.
  final List<T> items;

  /// Extracts a unique stable key from each item (e.g., entity ID).
  final StableKeyExtractor<T> keyExtractor;

  /// Builds the widget for each item.
  final StableItemBuilder<T> itemBuilder;

  /// Optional controller for load-more pagination.
  final BoundedListController<T>? listController;

  /// Widget shown at the bottom while loading more items.
  final Widget? loadingIndicator;

  /// Widget shown when the list is empty.
  final Widget? emptyWidget;

  /// Padding around the list.
  final EdgeInsetsGeometry? padding;

  /// Whether to use a [SliverList] internally (for use in CustomScrollView).
  final bool sliver;

  /// Scroll physics override.
  final ScrollPhysics? physics;

  /// Optional separator between items.
  final Widget? separator;

  /// How far from the bottom (in pixels) to trigger load-more.
  final double loadMoreThreshold;

  const StableKeyListView({
    super.key,
    required this.items,
    required this.keyExtractor,
    required this.itemBuilder,
    this.listController,
    this.loadingIndicator,
    this.emptyWidget,
    this.padding,
    this.sliver = false,
    this.physics,
    this.separator,
    this.loadMoreThreshold = 200.0,
  });

  @override
  State<StableKeyListView<T>> createState() => _StableKeyListViewState<T>();
}

class _StableKeyListViewState<T> extends State<StableKeyListView<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.listController != null) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.listController;
    if (controller == null || controller.isLoading || !controller.hasMore) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
      controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.emptyWidget != null) {
      return widget.emptyWidget!;
    }

    final itemCount = widget.items.length + _trailingCount;

    if (widget.sliver) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildItem(context, index),
          childCount: itemCount,
          findChildIndexCallback: (key) => _findChildIndex(key),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      itemCount: itemCount,
      // Use findChildIndexCallback for efficient key-based reordering.
      findChildIndexCallback: (key) => _findChildIndex(key),
      itemBuilder: (context, index) => _buildItem(context, index),
    );
  }

  int get _trailingCount {
    final controller = widget.listController;
    if (controller == null) return 0;
    return controller.isLoading ? 1 : 0;
  }

  Widget _buildItem(BuildContext context, int index) {
    // Loading indicator at the end.
    if (index >= widget.items.length) {
      return widget.loadingIndicator ??
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
    }

    final item = widget.items[index];
    final key = ValueKey<String>(widget.keyExtractor(item));

    Widget child = KeyedSubtree(
      key: key,
      child: widget.itemBuilder(context, item),
    );

    if (widget.separator != null && index < widget.items.length - 1) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [child, widget.separator!],
      );
    }

    return child;
  }

  int? _findChildIndex(Key key) {
    if (key is! ValueKey<String>) return null;
    final targetKey = key.value;
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.keyExtractor(widget.items[i]) == targetKey) {
        return i;
      }
    }
    return null;
  }
}
