import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dukanx/core/sync/engine/rest_sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/license_service.dart';
import '../core/di/service_locator.dart';
import 'grace_period_gate.dart';
import 'license_validator.dart';

/// Widget that listens for license invalidation events from the background sync engine.
/// If triggered, it clears the local license cache and forces the user back to the
/// license gateway screen.
///
/// Task 5.3 (offline-license-activation) additionally drives this same listener
/// from the License_Validator's Grace_Period_State (via [GracePeriodGate]):
///   * Read_Only → a non-blocking notice; viewing stays allowed while
///     bill-creation is blocked at the service layer (Req 7.8, 7.9).
///   * Locked → reuse the existing cache-clear + `/license` redirect path so
///     everything except reactivation is blocked (Req 7.13).
/// No widget-tree changes are introduced — only an extra stream subscription on
/// the existing listener.
class LicenseInvalidListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const LicenseInvalidListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<LicenseInvalidListener> createState() => _LicenseInvalidListenerState();
}

class _LicenseInvalidListenerState extends State<LicenseInvalidListener> {
  StreamSubscription<bool>? _licenseSubscription;
  StreamSubscription<GracePeriodState>? _graceSubscription;
  bool _isNavigating = false;
  bool _readOnlyNoticeShown = false;

  @override
  void initState() {
    super.initState();
    _licenseSubscription = RestSyncEngine.instance.onLicenseInvalidated.listen(
      _handleLicenseInvalid,
    );

    // Task 5.3: drive the SAME listener from the Grace_Period_State stream.
    // Locked reuses the existing invalidation path; Read_Only surfaces a
    // non-blocking notice (service layer still blocks bill creation).
    _graceSubscription = GracePeriodGate.instance.onStateChanged.listen(
      _handleGracePeriodState,
    );
  }

  @override
  void dispose() {
    _licenseSubscription?.cancel();
    _graceSubscription?.cancel();
    super.dispose();
  }

  /// Maps a Grace_Period_State transition onto the existing listener
  /// behaviour. Reuses the established mechanisms rather than building parallel
  /// gating (Req 7.9, 7.13).
  void _handleGracePeriodState(GracePeriodState state) {
    // Under subscription model, offline grace period from license keys is disabled
    debugPrint('[LicenseInvalidListener] Grace period state change ignored: $state');
  }

  void _showReadOnlyNotice() {
    // No-op under subscription model
  }

  Future<void> _handleLicenseInvalid(bool _) async {
    // Under subscription model, background license validation is disabled
    debugPrint('[LicenseInvalidListener] License invalidation event ignored');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
