import 'package:flutter/foundation.dart';

// PHASE 1 FIX A2: Real session readiness wait.
// Previously _loadUserSession() was a stub (Future.delayed(1000ms)) that
// did NOT actually wait for the auth session to settle. The splash then
// fired onComplete purely on the animation timer, so AuthGate frequently
// read `session.isAuthenticated == false` before restoreSession()'s
// network call (/auth/me) had finished — showing the login screen even
// for a logged-in user. See Phase 0 Section A.3.
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';

class SplashController extends ChangeNotifier {
  bool _animationReady = false;
  bool _appReady = false;

  bool get isReady => _animationReady && _appReady;

  bool get appReady => _appReady;

  Future<void> initializeApp() async {
    // Run initialization logic
    await Future.wait([
      _loadUserSession(),
      _loadAppConfig(),
      _initDatabase(),
    ]);

    _appReady = true;
    _maybeExit();
  }

  void onAnimationComplete() {
    _animationReady = true;
    _maybeExit();
  }

  void _maybeExit() {
    if (_animationReady && _appReady) {
      notifyListeners();
    }
  }

  // PHASE 1 FIX A2: Wait until SessionManager has reached a settled auth
  // state (either authenticated or definitively unauthenticated), so the
  // router does not read a transient "not authenticated" value. We poll
  // isInitialized because SessionManager is a plain ChangeNotifier and its
  // initial state is unknown until restoreSession()/authStateChanges()
  // resolves. A bounded timeout (8s) prevents an indefinite hang on a
  // totally broken network — after which AuthGate will (correctly) show
  // login, since we could not validate the session.
  Future<void> _loadUserSession() async {
    try {
      final session = sl<SessionManager>();
      const maxWait = Duration(seconds: 8);
      final deadline = DateTime.now().add(maxWait);
      while (!session.isInitialized && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint(
        '[SplashController] session ready: initialized=${session.isInitialized}, '
        'authenticated=${session.isAuthenticated}',
      );
    } catch (e) {
      // Non-fatal: if the locator is not ready yet, fall through and let
      // AuthGate show its own loading/error state. Do NOT swallow silently —
      // log so the failure is diagnosable.
      debugPrint('[SplashController] session wait failed: $e');
    }
  }

  Future<void> _loadAppConfig() async {
    await Future.delayed(const Duration(milliseconds: 1200));
  }

  Future<void> _initDatabase() async {
    await Future.delayed(const Duration(milliseconds: 1500));
  }
}

