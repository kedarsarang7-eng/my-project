// ============================================================================
// VIRTUALIZED LIST - Performance Optimization for Large Datasets (P2 FIX)
// ============================================================================

import 'package:flutter/material.dart';

/// A high-performance list that only renders visible items
class VirtualizedList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemExtent;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;
  final Widget? separator;
  final bool reverse;

  const VirtualizedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemExtent,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.scrollController,
    this.separator,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: physics ?? const ClampingScrollPhysics(),
      padding: padding,
      reverse: reverse,
      itemCount: separator != null ? items.length * 2 - 1 : items.length,
      itemExtent: separator != null ? null : itemExtent,
      prototypeItem: separator == null
          ? items.isNotEmpty
              ? itemBuilder(context, items.first, 0)
              : null
          : null,
      itemBuilder: (context, index) {
        if (separator != null && index.isOdd) {
          return separator!;
        }
        final itemIndex = separator != null ? index ~/ 2 : index;
        if (itemIndex >= items.length) return const SizedBox.shrink();
        return itemBuilder(context, items[itemIndex], itemIndex);
      },
      // Performance optimizations
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      cacheExtent: itemExtent * 3, // Cache 3 items above and below viewport
    );
  }
}

/// A virtualized table for enterprise data
class VirtualizedTable<T> extends StatefulWidget {
  final List<T> data;
  final List<VirtualizedColumn<T>> columns;
  final double rowHeight;
  final int rowsPerPage;
  final Function(T)? onRowTap;
  final List<Widget> Function(T)? actionsBuilder;
  final bool isLoading;
  final Widget? loadingWidget;
  final Widget? emptyWidget;

  const VirtualizedTable({
    super.key,
    required this.data,
    required this.columns,
    this.rowHeight = 56,
    this.rowsPerPage = 50,
    this.onRowTap,
    this.actionsBuilder,
    this.isLoading = false,
    this.loadingWidget,
    this.emptyWidget,
  });

  @override
  State<VirtualizedTable<T>> createState() => _VirtualizedTableState<T>();
}

class _VirtualizedTableState<T> extends State<VirtualizedTable<T>> {
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<T> get _sortedData {
    if (_sortColumnIndex == null) return widget.data;
    final sorted = List<T>.from(widget.data);
    final column = widget.columns[_sortColumnIndex!];
    sorted.sort((a, b) {
      final aVal = column.valueGetter(a);
      final bVal = column.valueGetter(b);
      if (aVal is Comparable && bVal is Comparable) {
        return _sortAscending
            ? aVal.compareTo(bVal)
            : bVal.compareTo(aVal);
      }
      return _sortAscending
          ? aVal.toString().compareTo(bVal.toString())
          : bVal.toString().compareTo(aVal.toString());
    });
    return sorted;
  }

  List<T> get _pagedData {
    final start = _currentPage * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, _sortedData.length);
    return _sortedData.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    if (widget.data.isEmpty) {
      return widget.emptyWidget ?? const Center(child: Text('No data'));
    }

    final totalPages = (widget.data.length / widget.rowsPerPage).ceil();
    final displayData = _pagedData;

    return Column(
      children: [
        // Header
        _buildHeader(),
        // Virtualized List
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: VirtualizedList<T>(
              items: displayData,
              itemExtent: widget.rowHeight,
              scrollController: _scrollController,
              itemBuilder: (context, item, index) => _buildRow(item),
            ),
          ),
        ),
        // Pagination
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: widget.rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < widget.columns.length; i++)
            Expanded(
              flex: widget.columns[i].flex,
              child: InkWell(
                onTap: widget.columns[i].sortable
                    ? () => _onSort(i)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        widget.columns[i].title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.columns[i].sortable) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _sortColumnIndex == i
                              ? (_sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward)
                              : Icons.unfold_more,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (widget.actionsBuilder != null)
            const SizedBox(width: 100), // Actions column
        ],
      ),
    );
  }

  Widget _buildRow(T item) {
    return InkWell(
      onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
      child: Container(
        height: widget.rowHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            for (final column in widget.columns)
              Expanded(
                flex: column.flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: column.builder(context, item),
                ),
              ),
            if (widget.actionsBuilder != null)
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actionsBuilder!(item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${_currentPage + 1} of $totalPages'),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }
}

/// Column definition for virtualized table
class VirtualizedColumn<T> {
  final String title;
  final int flex;
  final Widget Function(BuildContext context, T item) builder;
  final dynamic Function(T item) valueGetter;
  final bool sortable;

  VirtualizedColumn({
    required this.title,
    this.flex = 1,
    required this.builder,
    required this.valueGetter,
    this.sortable = false,
  });
}

/// Performance-optimized grid view
class VirtualizedGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;

  const VirtualizedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: items.length,
      // Performance optimizations
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      cacheExtent: 200,
      itemBuilder: (context, index) => itemBuilder(context, items[index], index),
    );
  }
}

/// Reusable pagination controls
class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final Function(int page) onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startItem = (currentPage * itemsPerPage) + 1;
    final endItem = ((currentPage + 1) * itemsPerPage).clamp(0, totalItems);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const Spacer(),
          IconButton(
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          ..._buildPageButtons(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons() {
    final buttons = <Widget>[];
    final maxVisible = 5;

    var start = (currentPage - maxVisible ~/ 2).clamp(0, totalPages - maxVisible);
    var end = (start + maxVisible).clamp(0, totalPages);

    if (end - start < maxVisible) {
      start = (end - maxVisible).clamp(0, totalPages);
    }

    for (var i = start; i < end; i++) {
      final isCurrent = i == currentPage;
      buttons.add(
        InkWell(
          onTap: () => onPageChanged(i),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCurrent ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.black,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
      if (i < end - 1) {
        buttons.add(const SizedBox(width: 4));
      }
    }

    return buttons;
  }
}
