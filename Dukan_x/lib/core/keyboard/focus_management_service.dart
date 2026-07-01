/// Focus Management Service - Logical Field Navigation
///
/// Provides:
/// - Logical focus flow (ENTER → next field)
/// - Focus trap for dialogs/modals
/// - Focus highlighting with visual ring
/// - Tab order management
/// - Escape key handling (back/cancel)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// FOCUSABLE FIELD WRAPPER
// ============================================================================

/// Wraps a field with proper focus handling for Tally-style navigation
class FocusableField extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onEnterPressed;
  final VoidCallback? onEscapePressed;
  final bool autofocus;
  final String? fieldId;
  final int? tabOrder;

  const FocusableField({
    super.key,
    required this.child,
    this.focusNode,
    this.onEnterPressed,
    this.onEscapePressed,
    this.autofocus = false,
    this.fieldId,
    this.tabOrder,
  });

  @override
  State<FocusableField> createState() => _FocusableFieldState();
}

class _FocusableFieldState extends State<FocusableField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (widget.onEnterPressed != null) {
        widget.onEnterPressed!();
        return KeyEventResult.handled;
      }
      // Move to next field
      _focusNode.nextFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.onEscapePressed != null) {
        widget.onEscapePressed!();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// FOCUS TRAP FOR DIALOGS
// ============================================================================

/// Traps focus within a dialog, preventing tab navigation outside
class FocusTrap extends StatelessWidget {
  final Widget child;
  final FocusNode? initialFocus;

  const FocusTrap({super.key, required this.child, this.initialFocus});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Focus(autofocus: true, child: child),
    );
  }
}

// ============================================================================
// KEYBOARD NAVIGABLE LIST
// ============================================================================

/// List that can be navigated with arrow keys
class KeyboardNavigableList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(T item, bool isSelected, bool isFocused) itemBuilder;
  final void Function(T item)? onItemSelected;
  final void Function(T item)? onItemActivated; // ENTER pressed
  final int? initialIndex;
  final double itemHeight;
  final ScrollController? scrollController;

  const KeyboardNavigableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onItemSelected,
    this.onItemActivated,
    this.initialIndex,
    this.itemHeight = 48,
    this.scrollController,
  });

  @override
  State<KeyboardNavigableList<T>> createState() =>
      _KeyboardNavigableListState<T>();
}

class _KeyboardNavigableListState<T> extends State<KeyboardNavigableList<T>> {
  late int _focusedIndex;
  late FocusNode _listFocusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex ?? 0;
    _listFocusNode = FocusNode();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _moveFocus(int delta) {
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(0, widget.items.length - 1);
    });
    _ensureVisible();
    widget.onItemSelected?.call(widget.items[_focusedIndex]);
  }

  void _ensureVisible() {
    final targetOffset = _focusedIndex * widget.itemHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _moveFocus(-1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        _moveFocus(1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.pageUp:
        _moveFocus(-10);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.pageDown:
        _moveFocus(10);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.home:
        setState(() => _focusedIndex = 0);
        _ensureVisible();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.end:
        setState(() => _focusedIndex = widget.items.length - 1);
        _ensureVisible();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        if (widget.items.isNotEmpty) {
          widget.onItemActivated?.call(widget.items[_focusedIndex]);
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _listFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.items.length,
        itemExtent: widget.itemHeight,
        itemBuilder: (context, index) {
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() => _focusedIndex = index);
                widget.onItemSelected?.call(widget.items[index]);
              },
              onDoubleTap: () {
                widget.onItemActivated?.call(widget.items[index]);
              },
              child: widget.itemBuilder(
                widget.items[index],
                index == _focusedIndex,
                _listFocusNode.hasFocus && index == _focusedIndex,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// KEYBOARD NAVIGABLE TABLE
// ============================================================================

/// Table row data for keyboard navigation
class KeyboardTableRow {
  final String id;
  final List<Widget> cells;
  final bool isSelectable;

  const KeyboardTableRow({
    required this.id,
    required this.cells,
    this.isSelectable = true,
  });
}

/// Table that can be navigated with arrow keys
class KeyboardNavigableTable extends StatefulWidget {
  final List<String> headers;
  final List<KeyboardTableRow> rows;
  final void Function(int rowIndex)? onRowSelected;
  final void Function(int rowIndex)? onRowActivated;
  final List<double>? columnWidths;

  const KeyboardNavigableTable({
    super.key,
    required this.headers,
    required this.rows,
    this.onRowSelected,
    this.onRowActivated,
    this.columnWidths,
  });

  @override
  State<KeyboardNavigableTable> createState() => _KeyboardNavigableTableState();
}

class _KeyboardNavigableTableState extends State<KeyboardNavigableTable> {
  int _focusedRow = 0;
  int _focusedCol = 0;
  late FocusNode _tableFocusNode;

  @override
  void initState() {
    super.initState();
    _tableFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _tableFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _moveRow(-1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        _moveRow(1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        _moveCol(-1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        _moveCol(1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        widget.onRowActivated?.call(_focusedRow);
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  void _moveRow(int delta) {
    setState(() {
      _focusedRow = (_focusedRow + delta).clamp(0, widget.rows.length - 1);
    });
    widget.onRowSelected?.call(_focusedRow);
  }

  void _moveCol(int delta) {
    setState(() {
      _focusedCol = (_focusedCol + delta).clamp(0, widget.headers.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _tableFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          // Header Row
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Row(
              children: widget.headers.asMap().entries.map((entry) {
                final width = widget.columnWidths?[entry.key];
                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Data Rows
          Expanded(
            child: ListView.builder(
              itemCount: widget.rows.length,
              itemBuilder: (context, rowIndex) {
                final row = widget.rows[rowIndex];
                final isSelected = rowIndex == _focusedRow;

                return GestureDetector(
                  onTap: () {
                    setState(() => _focusedRow = rowIndex);
                    widget.onRowSelected?.call(rowIndex);
                  },
                  onDoubleTap: () => widget.onRowActivated?.call(rowIndex),
                  child: Container(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                    child: Row(
                      children: row.cells.asMap().entries.map((entry) {
                        final width = widget.columnWidths?[entry.key];
                        final isCellFocused =
                            isSelected && entry.key == _focusedCol;

                        return SizedBox(
                          width: width,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: isCellFocused
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: entry.value,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXTENSION METHODS
// ============================================================================

extension FocusNodeExtensions on FocusNode {
  /// Move focus to next focusable node
  void moveToNext() {
    nextFocus();
  }

  /// Move focus to previous focusable node
  void moveToPrevious() {
    previousFocus();
  }
}
