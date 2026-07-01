// ============================================================================
// Trial Expired Gate — Full-screen blocker
// ============================================================================
// Blocks all app features when trial has expired.
// Shows upgrade CTA and allows logout only.
// Handles edge case: auto force-refresh if backend disagrees with cache.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../../../../providers/trial_subscription_provider.dart';

class TrialExpiredGateWidget extends ConsumerStatefulWidget {
  final Widget child;

  const TrialExpiredGateWidget({super.key, required this.child});

  @override
  ConsumerState<TrialExpiredGateWidget> createState() =>
      _TrialExpiredGateWidgetState();
}

class _TrialExpiredGateWidgetState
    extends ConsumerState<TrialExpiredGateWidget> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Force refresh on mount to catch backend/cache mismatch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefresh();
    });
  }

  Future<void> _checkAndRefresh() async {
    final notifier = ref.read(trialSubscriptionProvider.notifier);
    try {
      await notifier.refresh();
    } catch (_) {
      // Ignore — will use cached state
    }
  }

  @override
  Widget build(BuildContext context) {
    final trialState = ref.watch(trialSubscriptionProvider);

    // If no state yet or can access app, show normal content
    if (trialState == null || trialState.canAccessApp) {
      return widget.child;
    }

    // Show expired gate
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon with animation
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Trial Expired',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Your 14-day free trial has ended.\nUpgrade to continue using DukanX.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Upgrade button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/upgrade');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(
                        0xFF6C63FF,
                      ).withValues(alpha: 0.4),
                    ),
                    child: const Text(
                      'Upgrade Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Refresh button
                TextButton.icon(
                  onPressed: _refreshing
                      ? null
                      : () async {
                          setState(() => _refreshing = true);
                          try {
                            await ref
                                .read(trialSubscriptionProvider.notifier)
                                .forceRefresh();
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not refresh. Check your connection.',
                                  ),
                                ),
                              );
                            }
                          }
                          if (mounted) {
                            setState(() => _refreshing = false);
                          }
                        },
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white54),
                  label: Text(
                    _refreshing ? 'Checking...' : 'Already upgraded? Refresh',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),

                const SizedBox(height: 8),

                // Logout button
                TextButton(
                  onPressed: () {
                    context.go(RoutePaths.login);
                  },
                  child: const Text(
                    'Log out',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
