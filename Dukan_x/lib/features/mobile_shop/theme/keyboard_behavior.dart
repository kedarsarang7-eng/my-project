/// MobileShop Keyboard Behavior — Focus Traversal and Shortcuts (Dart)
///
/// Provides focus traversal support, logical tab-order, visible focus
/// indicators, and keyboard shortcuts for common mobile shop actions.
///
/// Requirements: 11.1, 11.5
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_shop_theme.dart';

// ─── Focus Indicator Decoration ──────────────────────────────────────────────

/// Decoration for visible focus indicators on keyboard navigation.
///
/// Uses a 2dp solid border matching the theme's focus color, with
/// sufficient contrast for WCAG AA compliance.
class FocusIndicatorDecoration extends StatelessWidget {
  /// The child widget to wrap with a focus indicator.
  final Widget child;

  /// Whether to show the focus indicator.
  final bool isFocused;

  /// Optional border radius matching the child's shape.
  final BorderRadius borderRadius;

  /// Focus ring width (2dp for visibility).
  final double ringWidth;

  /// Offset from the child edge (2dp outset).
  final double ringOffset;

  const FocusIndicatorDecoration({
    super.key,
    required this.child,
    required this.isFocused,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.ringWidth = 2.0,
    this.ringOffset = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFocused) return child;

    final focusColor = MobileShopTheme.of(context).focusIndicator;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius.add(BorderRadius.circular(ringOffset)),
        border: Border.all(color: focusColor, width: ringWidth),
      ),
      child: Padding(padding: EdgeInsets.all(ringOffset), child: child),
    );
  }
}

// ─── Focusable Action Item ───────────────────────────────────────────────────

/// Wraps an interactive item with proper focus handling and visible focus ring.
///
/// Ensures:
/// - Logical focus order (uses [FocusTraversalGroup] ordering)
/// - Visible focus indication on keyboard navigation
/// - Enter/Space activation (standard button behavior)
/// - 48dp minimum target size
class FocusableActionItem extends StatefulWidget {
  /// The interactive child widget.
  final Widget child;

  /// Called when the item is activated (tap or keyboard Enter/Space).
  final VoidCallback? onActivate;

  /// Semantic label for the action.
  final String semanticLabel;

  /// Optional focus node for external focus management.
  final FocusNode? focusNode;

  /// Whether this item can receive focus.
  final bool canRequestFocus;

  const FocusableActionItem({
    super.key,
    required this.child,
    this.onActivate,
    required this.semanticLabel,
    this.focusNode,
    this.canRequestFocus = true,
  });

  @override
  State<FocusableActionItem> createState() => _FocusableActionItemState();
}

class _FocusableActionItemState extends State<FocusableActionItem> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onActivate?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onActivate != null,
      enabled: widget.onActivate != null,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.canRequestFocus && widget.onActivate != null,
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: widget.onActivate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: MobileShopSpacing.touchTarget,
              minHeight: MobileShopSpacing.touchTarget,
            ),
            child: FocusIndicatorDecoration(
              isFocused: _isFocused,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Focus Traversal Group ───────────────────────────────────────────────────

/// Establishes a logical focus traversal group for a mobile shop section.
///
/// Groups related controls so tab navigation moves through them in a
/// predictable order before moving to the next section.
class MobileShopFocusGroup extends StatelessWidget {
  /// The children within this focus group.
  final Widget child;

  /// The traversal policy (defaults to reading order).
  final FocusTraversalPolicy? policy;

  const MobileShopFocusGroup({super.key, required this.child, this.policy});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: policy ?? ReadingOrderTraversalPolicy(),
      child: child,
    );
  }
}

// ─── Keyboard Shortcut Actions ───────────────────────────────────────────────

/// Common keyboard shortcuts for mobile shop workflows.
///
/// Provides standard shortcuts:
/// - Ctrl+R / Cmd+R: Refresh
/// - Ctrl+F / Cmd+F: Focus search
/// - Escape: Clear filter / Close panel
class MobileShopKeyboardShortcuts extends StatelessWidget {
  /// The child widget tree receiving shortcuts.
  final Widget child;

  /// Called when refresh shortcut is triggered.
  final VoidCallback? onRefresh;

  /// Called when search shortcut is triggered.
  final VoidCallback? onSearch;

  /// Called when escape is pressed (clear/close).
  final VoidCallback? onEscape;

  const MobileShopKeyboardShortcuts({
    super.key,
    required this.child,
    this.onRefresh,
    this.onSearch,
    this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    if (onRefresh != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyR, control: true)] =
          onRefresh!;
    }
    if (onSearch != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyF, control: true)] =
          onSearch!;
    }
    if (onEscape != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.escape)] = onEscape!;
    }

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}

// ─── Skip-to-Content Link ────────────────────────────────────────────────────

/// Provides a skip-to-main-content action for keyboard users.
///
/// Visually hidden until focused, then appears at the top of the viewport
/// allowing keyboard users to bypass navigation and jump to content.
class SkipToContentAction extends StatefulWidget {
  /// The focus node of the main content area to skip to.
  final FocusNode contentFocusNode;

  /// Label for the skip link.
  final String label;

  const SkipToContentAction({
    super.key,
    required this.contentFocusNode,
    this.label = 'Skip to main content',
  });

  @override
  State<SkipToContentAction> createState() => _SkipToContentActionState();
}

class _SkipToContentActionState extends State<SkipToContentAction> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isVisible = hasFocus);
      },
      child: GestureDetector(
        onTap: () => widget.contentFocusNode.requestFocus(),
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MobileShopSpacing.lg,
              vertical: MobileShopSpacing.sm,
            ),
            color: theme.colorScheme.primary,
            child: Text(
              widget.label,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
