// ============================================================================
// AppScaffold — Centralized Navigation + Back-Behavior Shell (Part 6)
// ============================================================================
// One widget every screen can use to get CONSISTENT back navigation across
// all 460+ screens and 19 business types:
//
//   • AppBar back button (visible when the route can pop).
//   • Android hardware-back / gesture handling via PopScope (so the AppBar
//     button and the system back button behave identically).
//   • Unsaved-changes guard: pass `hasUnsavedChanges: true` and a back press
//     shows a confirm dialog instead of discarding edits.
//   • Double-back-to-exit on roots: pass `isRoot: true` to require two presses
//     before leaving the app (prevents accidental exits).
//
// This replaces per-screen duplication (each screen otherwise reimplements
// PopScope + BackButton + dialogs). Existing screens keep working — AppScaffold
// is purely additive and the DesktopContentContainer header still renders its
// own back affordance; AppScaffold handles the SYSTEM/gesture side and the
// unsaved-changes lifecycle.
// ============================================================================

import 'package:flutter/material.dart';
import 'confirmation_dialog.dart';

/// Callback that decides whether a back press may proceed immediately.
/// Return true to allow the pop, false to block it (e.g. show a dialog).
typedef BackGuardCallback = Future<bool> Function();

class AppScaffold extends StatefulWidget {
  /// Standard Scaffold body.
  final Widget body;

  /// Optional AppBar title.
  final String? title;

  /// Optional AppBar actions (right side).
  final List<Widget>? actions;

  /// Optional leading widget. If null and the route can pop, a back button is
  /// shown automatically.
  final Widget? leading;

  /// Background color forwarded to [Scaffold].
  final Color? backgroundColor;

  /// AppBar background color.
  final Color? appBarBackgroundColor;

  /// Foreground color for AppBar title/icons.
  final Color? foregroundColor;

  /// When true, a back press (AppBar button OR system back) first shows a
  /// "discard changes?" confirmation. Pair with [discardConfirmText].
  final bool hasUnsavedChanges;

  /// When true, the screen is a navigation root: a single back press shows a
  /// "press back again to exit" toast and only the second press exits the app.
  final bool isRoot;

  /// Override the AppBar entirely (advanced). When provided, [title]/[actions]
  /// are ignored and no automatic AppBar back button is added.
  final PreferredSizeWidget? appBar;

  /// Whether to wrap the body in SafeArea (default true).
  final bool useSafeArea;

  /// Optional resize handling for the keyboard.
  final bool resizeToAvoidBottomInset;

  /// Floating action button forwarded to [Scaffold].
  final Widget? floatingActionButton;

  /// Bottom navigation bar forwarded to [Scaffold].
  final Widget? bottomNavigationBar;

  /// Drawer forwarded to [Scaffold].
  final Widget? drawer;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.appBarBackgroundColor,
    this.foregroundColor,
    this.hasUnsavedChanges = false,
    this.isRoot = false,
    this.appBar,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // Double-back-to-exit bookkeeping (root screens only).
  DateTime? _lastBackPress;
  static const _exitGrace = Duration(seconds: 2);

  // Tracks whether an unsaved-changes dialog is already on screen, so a fast
  // double back-press doesn't stack two dialogs.
  bool _guardDialogOpen = false;
  // Re-entrancy guard: the AppBar button and PopScope both run _onBack, and a
  // pop can route back through PopScope. This prevents infinite recursion.
  bool _resolving = false;

  /// Resolve whether the current back press should pop or be intercepted.
  Future<bool> _onBack() async {
    if (_resolving) return false;
    _resolving = true;
    try {
      return await _resolveBack();
    } finally {
      _resolving = false;
    }
  }

  Future<bool> _resolveBack() async {
    // 1. Unsaved-changes guard takes precedence.
    if (widget.hasUnsavedChanges && !_guardDialogOpen) {
      return await _confirmDiscard();
    }

    // 2. Root double-back-to-exit.
    if (widget.isRoot) {
      final now = DateTime.now();
      if (_lastBackPress == null ||
          now.difference(_lastBackPress!) > _exitGrace) {
        _lastBackPress = now;
        _showExitToast();
        return false; // block this press; require a second one
      }
      // Second press within grace → allow app exit.
      return true;
    }

    // 3. Normal pop.
    return true;
  }

  Future<bool> _confirmDiscard() async {
    _guardDialogOpen = true;
    final result = await ConfirmationDialog.show(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
      confirmText: 'Discard',
      cancelText: 'Keep Editing',
      icon: Icons.warning_amber_rounded,
      isDangerous: true,
    );
    _guardDialogOpen = false;
    return result;
  }

  void _showExitToast() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final effectiveLeading = widget.leading ??
        (canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Go Back',
                onPressed: () async {
                  // Guard already ran; pop directly (NOT maybePop, which would
                  // re-enter PopScope → _onBack → recursion).
                  if (await _onBack() && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              )
            : null);

    final appBar = widget.appBar ??
        AppBar(
          title: widget.title != null
              ? Text(
                  widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          leading: effectiveLeading,
          actions: widget.actions,
          backgroundColor: widget.appBarBackgroundColor,
          foregroundColor: widget.foregroundColor,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false, // we manage leading explicitly
        );

    Widget body = widget.body;
    if (widget.useSafeArea) {
      body = SafeArea(child: body);
    }

    // PopScope unifies Android hardware-back, gesture nav, and the AppBar
    // button through one decision point (_onBack). canPop=false intercepts the
    // system pop so onPopInvokedWithResult runs our guard logic.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Guard decided we may leave; pop directly. maybePop() would re-enter
        // this callback (canPop is false) → recursion.
        if (await _onBack() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        appBar: appBar,
        body: body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
        drawer: widget.drawer,
      ),
    );
  }
}
