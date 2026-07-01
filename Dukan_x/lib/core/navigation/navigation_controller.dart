import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_screens.dart';

// ============================================================================
// ENTERPRISE NAVIGATION CONTROLLER
// ============================================================================
// Production-hardened navigation controller with:
// - Build-guard protection (prevents setState during build)
// - Frame-safe navigation (defers to post-frame callback)
// - Debouncing (prevents rapid navigation causing jank)
// - History tracking (for back navigation support)
//
// Author: DukanX Engineering
// Version: 2.0.0 (Enterprise Hardened)
// ============================================================================

/// State class for navigation
class NavigationState {
  final AppScreen currentScreen;
  final List<AppScreen> history;
  final bool isNavigating;

  const NavigationState({
    this.currentScreen = AppScreen.executiveDashboard,
    this.history = const [],
    this.isNavigating = false,
  });

  NavigationState copyWith({
    AppScreen? currentScreen,
    List<AppScreen>? history,
    bool? isNavigating,
  }) {
    return NavigationState(
      currentScreen: currentScreen ?? this.currentScreen,
      history: history ?? this.history,
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }

  /// Whether a back navigation is possible
  bool get canGoBack => history.isNotEmpty;
}

/// Navigation Controller using Riverpod Notifier pattern (Riverpod 3.x compatible)
class NavigationController extends Notifier<NavigationState> {
  static const int _maxHistorySize = 20;
  bool _buildInProgress = false;

  @override
  NavigationState build() => const NavigationState();

  /// Mark build as in progress (called by widgets during build)
  /// This prevents navigation from happening during a build phase.
  void markBuildInProgress() {
    _buildInProgress = true;
    // Auto-reset after frame to prevent stuck state
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _buildInProgress = false;
    });
  }

  /// Navigate to a specific screen safely.
  /// Uses frame-safe scheduling to ensure navigation happens AFTER the current frame,
  /// preventing "setState() called during build" or pointer event clashes.
  void navigateTo(AppScreen screen) {
    if (state.currentScreen == screen) return;
    if (state.isNavigating) return; // Debounce rapid navigation

    // If we're in a build phase, defer to post-frame
    if (_buildInProgress ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!state.isNavigating) {
          _performNavigation(screen);
        }
      });
      return;
    }

    // If during microtask phase, use microtask scheduling (existing behavior)
    state = state.copyWith(isNavigating: true);
    scheduleMicrotask(() {
      _performNavigation(screen);
    });
  }

  /// Internal navigation execution
  void _performNavigation(AppScreen screen) {
    // Add current screen to history before navigating
    List<AppScreen> newHistory = List.from(state.history);
    if (state.currentScreen != AppScreen.unknown) {
      newHistory.add(state.currentScreen);
      // Trim history if too large
      while (newHistory.length > _maxHistorySize) {
        newHistory.removeAt(0);
      }
    }

    state = NavigationState(
      currentScreen: screen,
      history: newHistory,
      isNavigating: false,
    );

    if (kDebugMode) {
      debugPrint('[NavController] Navigated to: ${screen.name}');
    }
  }

  /// Navigate back to the previous screen
  void goBack() {
    if (state.history.isEmpty) return;

    final newHistory = List<AppScreen>.from(state.history);
    final previousScreen = newHistory.removeLast();

    state = NavigationState(
      currentScreen: previousScreen,
      history: newHistory,
      isNavigating: false,
    );

    if (kDebugMode) {
      debugPrint('[NavController] Navigated back to: ${previousScreen.name}');
    }
  }

  /// Navigate by string ID (for compatibility with legacy sidebar)
  void navigateById(String id) {
    final screen = AppScreen.fromId(id);
    if (screen == AppScreen.unknown) {
      debugPrint('[NavController] Warning: Unknown navigation id: $id');
      return;
    }
    navigateTo(screen);
  }

  /// Navigate to a screen, replacing current (no history addition)
  void replaceWith(AppScreen screen) {
    if (state.currentScreen == screen) return;

    scheduleMicrotask(() {
      state = state.copyWith(currentScreen: screen);
    });

    if (kDebugMode) {
      debugPrint('[NavController] Replaced with: ${screen.name}');
    }
  }

  /// Clear navigation history
  void clearHistory() {
    state = state.copyWith(history: []);
  }

  /// Reset to initial screen and clear history
  void reset() {
    state = const NavigationState();
  }

  /// Convenience getter for current screen
  AppScreen get currentScreen => state.currentScreen;

  /// Convenience getter for history
  List<AppScreen> get history => state.history;

  /// Convenience getter for canGoBack
  bool get canGoBack => state.canGoBack;
}

/// Riverpod provider for the NavigationController
final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationState>(
      NavigationController.new,
    );
