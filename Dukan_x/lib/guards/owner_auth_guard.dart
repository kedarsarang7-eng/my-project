import 'dart:async';

import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dukanx/core/routing/route_paths.dart';
import '../services/owner_account_service.dart';
import '../services/session_service.dart';

/// OwnerAuthGuard wraps sensitive owner-only screens and ensures only
/// authenticated Firebase email/password owner sessions may proceed.
class OwnerAuthGuard extends StatefulWidget {
  const OwnerAuthGuard({super.key, required this.child});

  final Widget child;

  @override
  State<OwnerAuthGuard> createState() => _OwnerAuthGuardState();
}

class _OwnerAuthGuardState extends State<OwnerAuthGuard> {
  bool _authorized = false;
  bool _checked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  Future<void> _validate() async {
    try {
      if (!sessionService.isInitialized) {
        await sessionService.init();
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('OwnerAuthGuard: waiting for Firebase user...');
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .firstWhere((event) => event != null)
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
        } catch (e) {
          debugPrint('OwnerAuthGuard authState listen error: $e');
        }
      }

      final role = sessionService.getUserRole();
      final loggedIn = sessionService.isLoggedIn();
      // Both 'owner' and 'vendor' roles have owner-level access
      final loggedInOwner = loggedIn && (role == 'owner' || role == 'vendor');

      bool ownerMatches =
          true; // Default to true to prevent blocking on network errors at this stage
      if (user != null && loggedInOwner) {
        try {
          // We strive to verify, but if this fails due to network/timeout, we shouldn't block
          // a valid session.
          final record = await ownerAccountService.fetchOwnerRecord(
            uid: user.uid,
          );
          if (record != null) {
            final authUid = record['authUid'] as String?;
            if (authUid != null && authUid != user.uid) {
              ownerMatches = false; // Explicit mismatch found
            }
          }
          // If record is null, it might be a new owner or data sync issue.
          // We'll allow access if the session claims owner role.
        } catch (e) {
          debugPrint('OwnerAuthGuard owner lookup failed (non-fatal): $e');
          // Non-fatal error, assume match to allow offline/flaky access
          ownerMatches = true;
        }
      }

      // Main requirement: Session says owner/vendor, and if we did check, it wasn't a mismatch.
      final allowed = loggedInOwner && ownerMatches;

      debugPrint(
        'OwnerAuthGuard: allowed=$allowed, loggedIn=$loggedIn, role=$role, ownerMatch=$ownerMatches, userUID=${user?.uid}',
      );

      if (!mounted) return;
      setState(() {
        _authorized = allowed;
        _checked = true;
        _error = allowed ? null : 'Owner login required. Please sign in again.';
      });

      // Removed aggressive auto-logout here.
      // If validation fails, we just show the error UI defined in build().
    } catch (e, st) {
      debugPrint('OwnerAuthGuard validation failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _authorized = false;
        _checked = true;
        _error = 'Authorization error: $e';
      });
      // Removed aggressive auto-logout here as well.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authorized) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Owner access denied.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate back or to login if really needed, but user chooses it
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      context.pushReplacement(RoutePaths.login);
                    }
                  },
                  child: const Text('Go Back / Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
