// ============================================================================
// APP LIFECYCLE OBSERVER
// ============================================================================
// Global lifecycle observer to trigger sync on app resume.
//
// SAFETY GUARANTEES:
// - Does NOT modify SyncManager internals
// - Does NOT replace autoStart behavior
// - Only acts as a "nudge" on resume
// - Defensive guard prevents double sync
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/widgets.dart';
import '../sync/engine/sync_engine.dart';

/// Global lifecycle observer that triggers sync on app resume
///
/// This is a SAFE, NON-INTRUSIVE addition that:
/// - Listens for AppLifecycleState.resumed
/// - Triggers SyncEngine.triggerSync() as a nudge
/// - Does NOT cause double sync (Engine has internal guards)
/// - Does NOT interfere with autoStart behavior
class AppLifecycleObserver with WidgetsBindingObserver {
  static AppLifecycleObserver? _instance;

  /// Singleton instance
  static AppLifecycleObserver get instance {
    _instance ??= AppLifecycleObserver._();
    return _instance!;
  }

  AppLifecycleObserver._();

  bool _isRegistered = false;

  /// Register the observer with WidgetsBinding
  ///
  /// Safe to call multiple times - only registers once
  void register() {
    if (_isRegistered) return;

    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
    debugPrint('[AppLifecycleObserver] Registered');
  }

  /// Unregister the observer
  void unregister() {
    if (!_isRegistered) return;

    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
    debugPrint('[AppLifecycleObserver] Unregistered');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// Called when app is resumed from background
  ///
  /// SAFE: SyncEngine internal guards prevent:
  /// - Double sync (if already processing, triggerSync() is no-op)
  void _onAppResumed() {
    debugPrint('[AppLifecycleObserver] App resumed - nudging SyncEngine');

    try {
      SyncEngine.instance.triggerSync();
    } catch (e) {
      // Defensive: Don't crash app if SyncEngine not initialized
      debugPrint('[AppLifecycleObserver] SyncEngine not ready: $e');
    }
  }
}
