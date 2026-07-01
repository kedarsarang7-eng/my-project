import 'dart:async';
import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../core/offline/offline_search_service.dart' as offline;

/// Reusable Search Widget for DukanX
/// 
/// Provides a complete search experience with:
/// - Debounced search input
/// - Autocomplete suggestions
/// - Infinite scroll pagination
/// - Pull-to-refresh
/// - Empty and error states
/// - Offline indicator
/// 
/// Usage:
/// ```dart
/// SearchWidget<Customer>(
///   entityType: SearchEntityType.customers,
///   itemBuilder: (customer) => ListTile(title: Text(customer.name)),
///   onItemSelected: (customer) => Navigator.pop(context, customer),
///   hintText: 'Search customers...',
/// )
/// ```
class SearchWidget<T> extends StatefulWidget {
  final SearchEntityType entityType;
  final Widget Function(T item) itemBuilder;
  final void Function(T item)? onItemSelected;
  final String hintText;
  final String? emptyText;
  final String? errorText;
  final int pageSize;
  final Duration debounceDuration;
  final bool showSuggestions;
  final Widget Function(String query)? emptyBuilder;
  final Widget? loadingWidget;
  final List<Widget>? actions;
  final Widget? filterChip;
  final AdvancedSearchRequest? advancedFilter;

  const SearchWidget({
    super.key,
    required this.entityType,
    required this.itemBuilder,
    this.onItemSelected,
    this.hintText = 'Search...',
    this.emptyText,
    this.errorText,
    this.pageSize = 20,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.showSuggestions = true,
    this.emptyBuilder,
    this.loadingWidget,
    this.actions,
    this.filterChip,
    this.advancedFilter,
  });

  @override
  State<SearchWidget<T>> createState() => _SearchWidgetState<T>();
}

class _SearchWidgetState<T> extends State<SearchWidget<T>> {
  final SearchService _searchService = SearchService();
  final offline.OfflineSearchService _offlineSearchService = offline.OfflineSearchService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  
  List<T> _items = [];
  List<SearchSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  bool _isOffline = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
    
    // Initial load if no search query required
    if (!widget.showSuggestions) {
      _performSearch();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(widget.debounceDuration, () {
      _currentPage = 1;
      _items = [];
      _hasMore = true;
      
      if (_searchController.text.isNotEmpty) {
        _performSearch();
        if (widget.showSuggestions) {
          _loadSuggestions();
        }
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _searchController.text.isNotEmpty) {
      _loadSuggestions();
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _performSearch() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isOffline = false;
    });

    try {
      SearchResult<T> result;

      if (widget.advancedFilter != null) {
        // Use advanced search with filters
        result = await _searchService.advancedSearch<T>(
          entityType: widget.entityType,
          request: AdvancedSearchRequest(
            query: _searchController.text,
            filters: widget.advancedFilter!.filters,
            page: _currentPage,
            pageSize: widget.pageSize,
            sortBy: widget.advancedFilter!.sortBy ?? 'createdAt',
            sortOrder: widget.advancedFilter!.sortOrder ?? 'desc',
          ),
          fromJson: (json) => _parseItem(json) as T,
        );
      } else {
        // Use basic search
        result = await _searchService.search<T>(
          entityType: widget.entityType,
          params: SearchParams(
            query: _searchController.text,
            page: _currentPage,
            pageSize: widget.pageSize,
          ),
          fromJson: (json) => _parseItem(json) as T,
        );
      }

      setState(() {
        if (_currentPage == 1) {
          _items = result.results;
        } else {
          _items.addAll(result.results);
        }
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } on SearchOfflineException {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
      // Fallback to offline search
      await _performOfflineSearch();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    // Route through offline search when we're in offline mode
    if (_isOffline) {
      try {
        await _performOfflineSearch();
      } finally {
        if (mounted) setState(() => _isLoadingMore = false);
      }
      return;
    }

    try {
      final result = await _searchService.search<T>(
        entityType: widget.entityType,
        params: SearchParams(
          query: _searchController.text,
          page: _currentPage,
          pageSize: widget.pageSize,
        ),
        fromJson: (json) => _parseItem(json) as T,
      );

      setState(() {
        _items.addAll(result.results);
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } on SearchOfflineException {
      // Connection lost mid-scroll — switch to offline mode
      setState(() => _isOffline = true);
      await _performOfflineSearch();
      if (mounted) setState(() => _isLoadingMore = false);
    } catch (e) {
      setState(() {
        _currentPage--;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadSuggestions() async {
    if (!widget.showSuggestions) return;

    if (_isOffline) {
      // Offline: use recent items as suggestions
      try {
        final recentItems = await _offlineSearchService.getRecentItems(
          widget.entityType,
          limit: 8,
        );

        if (!mounted) return;
        setState(() {
          _suggestions = recentItems.map((item) {
            final displayText = item['name'] as String? ??
                item['customerName'] as String? ??
                item['invoiceNumber'] as String? ??
                item['jobNumber'] as String? ??
                item['challanNumber'] as String? ??
                item['id']?.toString() ??
                '';
            return SearchSuggestion(
              text: displayText,
              type: widget.entityType.name,
              id: item['id']?.toString() ?? '',
              highlight: item['phone'] as String? ??
                  item['category'] as String? ??
                  item['status'] as String?,
            );
          }).toList();
        });
      } catch (_) {
        // Silently fail — suggestions are optional
      }
      return;
    }

    // Online: use the HTTP /suggest endpoint
    try {
      final suggestions = await _searchService.getSuggestions(
        query: _searchController.text,
        entityType: widget.entityType,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (_) {
      // Silently fail — suggestions are optional
    }
  }

  Future<void> _performOfflineSearch() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Build filters from advancedFilter if present
      Map<String, dynamic>? filters;
      if (widget.advancedFilter?.filters != null) {
        filters = widget.advancedFilter!.filters!.map(
          (key, value) => MapEntry(key, value.eq ?? value.match),
        );
      }

      final offlineResult = await _offlineSearchService.search(
        widget.entityType,
        _searchController.text,
        page: _currentPage,
        pageSize: widget.pageSize,
        filters: filters,
      );

      if (!mounted) return;

      // Convert offline SearchResult<Map> → widget's List<T>
      final typedItems = offlineResult.results
          .map((json) => _parseItem(json) as T)
          .toList();

      setState(() {
        if (_currentPage == 1) {
          _items = typedItems;
        } else {
          _items.addAll(typedItems);
        }
        _hasMore = offlineResult.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Offline search failed: $e';
        _isLoading = false;
      });
    }
  }

  dynamic _parseItem(Map<String, dynamic> json) {
    // The fromJson function will be provided by the caller
    // This is just a placeholder that gets replaced
    return json;
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    _searchController.text = suggestion.text;
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
    });
    _performSearch();
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _items = [];
    _hasMore = true;
    await _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        if (widget.filterChip != null) ...[
          const SizedBox(height: 8),
          widget.filterChip!,
        ],
        if (_isOffline) _buildOfflineBanner(),
        if (_suggestions.isNotEmpty && _focusNode.hasFocus)
          _buildSuggestionsList(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _items = [];
                      _suggestions = [];
                    });
                  },
                ),
              if (widget.actions != null) ...widget.actions!,
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _focusNode.unfocus();
          _performSearch();
        },
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange.shade800, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline mode - showing cached results',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Material(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.search, size: 20),
              title: Text(suggestion.text),
              subtitle: suggestion.highlight != null
                  ? Text(
                      suggestion.highlight!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _onSuggestionSelected(suggestion),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _items.isEmpty) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_items.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return _buildLoadMoreIndicator();
          }

          final item = _items[index];
          return InkWell(
            onTap: widget.onItemSelected != null
                ? () => widget.onItemSelected!(item)
                : null,
            child: widget.itemBuilder(item),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(_searchController.text);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyText ?? 'No results found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            widget.errorText ?? 'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Search dialog for quick selection
/// 
/// Shows a full-screen search dialog that returns the selected item.
/// 
/// Usage:
/// ```dart
/// final customer = await showSearchDialog<Customer>(
///   context: context,
///   entityType: SearchEntityType.customers,
///   itemBuilder: (c) => ListTile(title: Text(c.name)),
///   hintText: 'Select customer...',
/// );
/// ```
Future<T?> showSearchDialog<T>({
  required BuildContext context,
  required SearchEntityType entityType,
  required Widget Function(T item) itemBuilder,
  String hintText = 'Search...',
  String title = 'Search',
  AdvancedSearchRequest? advancedFilter,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search widget
              Expanded(
                child: SearchWidget<T>(
                  entityType: entityType,
                  itemBuilder: itemBuilder,
                  onItemSelected: (item) => Navigator.pop(context, item),
                  hintText: hintText,
                  advancedFilter: advancedFilter,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Inline search field with results dropdown
/// 
/// Useful for embedding search in forms or inline layouts.
class InlineSearchField<T> extends StatefulWidget {
  final SearchEntityType entityType;
  final Widget Function(T item) itemBuilder;
  final void Function(T item) onSelected;
  final String hintText;
  final double maxDropdownHeight;

  const InlineSearchField({
    super.key,
    required this.entityType,
    required this.itemBuilder,
    required this.onSelected,
    this.hintText = 'Search...',
    this.maxDropdownHeight = 300,
  });

  @override
  State<InlineSearchField<T>> createState() => _InlineSearchFieldState<T>();
}

class _InlineSearchFieldState<T> extends State<InlineSearchField<T>> {
  final SearchService _searchService = SearchService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  List<T> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_controller.text.length >= 2) {
        _performSearch();
      } else {
        _hideOverlay();
      }
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    try {
      final result = await _searchService.search<T>(
        entityType: widget.entityType,
        params: SearchParams(
          query: _controller.text,
          page: 1,
          pageSize: 10,
        ),
        fromJson: (json) => json as T,
      );

      setState(() {
        _results = result.results;
        _isLoading = false;
      });

      _showOverlay();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showOverlay() {
    _hideOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.maxDropdownHeight,
              ),
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No results'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return InkWell(
                          onTap: () {
                            widget.onSelected(item);
                            _controller.text = _extractDisplayText(item);
                            _hideOverlay();
                            _focusNode.unfocus();
                          },
                          child: widget.itemBuilder(item),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  String _extractDisplayText(T item) {
    // Try to extract a display string from the item
    if (item is Map) {
      return item['name'] ??
          item['customerName'] ??
          item['productName'] ??
          item.toString();
    }
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (_) => _onTextChanged(),
      ),
    );
  }
}
