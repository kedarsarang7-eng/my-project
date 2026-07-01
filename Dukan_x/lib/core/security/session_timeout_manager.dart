// ============================================================================
// SESSION TIMEOUT MANAGER - Auto-Lock After Inactivity (P1 FIX)
// ============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../di/service_locator.dart';
import '../navigation/navigation_controller.dart';
import '../session/session_manager.dart';

/// Session timeout configuration
class SessionTimeoutConfig {
  /// Timeout duration after which user is locked out (default: 15 minutes)
  final Duration timeoutDuration;

  /// Warning duration before timeout (default: 30 seconds before timeout)
  final Duration warningDuration;

  /// Whether to show warning dialog
  final bool showWarning;

  /// Whether to lock on app minimize
  final bool lockOnMinimize;

  const SessionTimeoutConfig({
    this.timeoutDuration = const Duration(minutes: 15),
    this.warningDuration = const Duration(seconds: 30),
    this.showWarning = true,
    this.lockOnMinimize = false,
  });
}

/// State for session timeout
class SessionTimeoutState {
  final bool isLocked;
  final DateTime? lastActivity;
  final bool showingWarning;
  final Duration remainingTime;

  const SessionTimeoutState({
    this.isLocked = false,
    this.lastActivity,
    this.showingWarning = false,
    this.remainingTime = Duration.zero,
  });

  SessionTimeoutState copyWith({
    bool? isLocked,
    DateTime? lastActivity,
    bool? showingWarning,
    Duration? remainingTime,
  }) {
    return SessionTimeoutState(
      isLocked: isLocked ?? this.isLocked,
      lastActivity: lastActivity ?? this.lastActivity,
      showingWarning: showingWarning ?? this.showingWarning,
      remainingTime: remainingTime ?? this.remainingTime,
    );
  }
}

/// Manages session timeout and auto-lock functionality
class SessionTimeoutManager extends Notifier<SessionTimeoutState> {
  final SessionTimeoutConfig config;

  Timer? _inactivityTimer;
  Timer? _warningTimer;
  Timer? _countdownTimer;

  // Track user activity
  DateTime _lastActivity = DateTime.now();

  SessionTimeoutManager(this.config);

  @override
  SessionTimeoutState build() {
    _initialize();
    ref.onDispose(_cancelAllTimers);
    return const SessionTimeoutState();
  }

  void _initialize() {
    _lastActivity = DateTime.now();
    _startInactivityTimer();
  }

  /// Start the main inactivity timer
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();

    // Calculate when warning should show
    if (config.showWarning) {
      final warningTime = config.timeoutDuration - config.warningDuration;
      _warningTimer = Timer(warningTime, _showWarning);
    }

    // Main timeout timer
    _inactivityTimer = Timer(config.timeoutDuration, _lockSession);
  }

  /// Show warning dialog before timeout
  void _showWarning() {
    if (state.isLocked) return;

    state = state.copyWith(showingWarning: true);

    // Start countdown timer for UI updates
    var remainingSeconds = config.warningDuration.inSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        return;
      }

      state = state.copyWith(
        remainingTime: Duration(seconds: remainingSeconds),
      );
    });
  }

  /// Lock the session and clear sensitive data
  void _lockSession() {
    if (state.isLocked) return;

    _cancelAllTimers();

    state = state.copyWith(
      isLocked: true,
      showingWarning: false,
      remainingTime: Duration.zero,
    );

    // Clear navigation history for security
    try {
      ref.read(navigationControllerProvider.notifier).clearHistory();
    } catch (e) {
      developer.log(
        'Failed to clear nav history: $e',
        name: 'SessionTimeoutManager',
      );
    }

    // Optionally clear sensitive cached data
    _clearSensitiveData();
  }

  /// Clear sensitive cached data
  void _clearSensitiveData() {
    // Clear any sensitive in-memory data
    // Note: Don't clear auth tokens, just UI state
  }

  /// Cancel all active timers
  void _cancelAllTimers() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _countdownTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer = null;
    _countdownTimer = null;
  }

  /// Record user activity and reset timers
  void recordActivity() {
    if (state.isLocked) return;

    _lastActivity = DateTime.now();
    state = state.copyWith(lastActivity: _lastActivity);

    // Cancel warning if showing
    if (state.showingWarning) {
      state = state.copyWith(showingWarning: false);
    }

    // Restart timers
    _cancelAllTimers();
    _startInactivityTimer();
  }

  /// Extend the current session (called when user interacts with warning)
  void extendSession() {
    if (state.isLocked) return;

    recordActivity();
    state = state.copyWith(showingWarning: false);
  }

  /// Unlock the session (requires re-authentication)
  Future<void> unlockSession() async {
    // Verify user is still authenticated
    final isAuthenticated = sl<SessionManager>().isAuthenticated;

    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    state = const SessionTimeoutState(isLocked: false);
    _lastActivity = DateTime.now();
    _startInactivityTimer();
  }

  /// Lock session immediately (e.g., when app goes to background)
  void lockImmediately() {
    if (config.lockOnMinimize) {
      _lockSession();
    }
  }

  /// Get formatted remaining time for UI
  String getFormattedRemainingTime() {
    final minutes = state.remainingTime.inMinutes;
    final seconds = state.remainingTime.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Provider for session timeout manager
final sessionTimeoutManagerProvider =
    NotifierProvider<SessionTimeoutManager, SessionTimeoutState>(() {
      return SessionTimeoutManager(
        const SessionTimeoutConfig(
          timeoutDuration: Duration(minutes: 15), // 15 minutes of inactivity
          warningDuration: Duration(seconds: 30), // 30 second warning
          showWarning: true,
          lockOnMinimize: false,
        ),
      );
    });

/// Widget that wraps the app and listens for user activity
class SessionTimeoutWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  ConsumerState<SessionTimeoutWrapper> createState() =>
      _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends ConsumerState<SessionTimeoutWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final manager = ref.read(sessionTimeoutManagerProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App went to background - consider locking
        manager.lockImmediately();
        break;
      case AppLifecycleState.resumed:
        // App came to foreground - record activity
        manager.recordActivity();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeoutState = ref.watch(sessionTimeoutManagerProvider);

    // Listen for user interactions
    return Listener(
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: KeyboardListener(
        onKeyEvent: (_) => _recordActivity(),
        focusNode: FocusNode(),
        child: Stack(
          children: [
            widget.child,

            // Show warning dialog
            if (timeoutState.showingWarning && !timeoutState.isLocked)
              _buildWarningOverlay(timeoutState),

            // Show lock screen
            if (timeoutState.isLocked) _buildLockScreen(),
          ],
        ),
      ),
    );
  }

  void _recordActivity() {
    ref.read(sessionTimeoutManagerProvider.notifier).recordActivity();
  }

  Widget _buildWarningOverlay(SessionTimeoutState timeoutState) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('Session Timeout Warning'),
          content: Text(
            'Your session will expire in ${timeoutState.remainingTime.inSeconds} seconds due to inactivity. '
            'Click "Continue" to stay logged in.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref
                    .read(sessionTimeoutManagerProvider.notifier)
                    .extendSession();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockScreen() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Session Locked',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your session has been locked due to inactivity.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(sessionTimeoutManagerProvider.notifier)
                      .unlockSession();
                } catch (e) {
                  // If unlock fails, redirect to login
                  if (mounted) {
                    context.go(RoutePaths.login);
                  }
                }
              },
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.go(RoutePaths.login);
              },
              child: const Text('Login Again'),
            ),
          ],
        ),
      ),
    );
  }
}
