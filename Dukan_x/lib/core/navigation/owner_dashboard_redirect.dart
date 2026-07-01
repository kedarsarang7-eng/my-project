import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_state_providers.dart';
import '../../models/business_type.dart';

/// Pushes [replacementNamed] (default `/owner_dashboard`) and removes this route.
///
/// Used to consolidate legacy dashboard URLs onto the single shell entrypoint.
class OwnerDashboardRedirect extends StatefulWidget {
  final String replacementNamed;

  const OwnerDashboardRedirect({
    super.key,
    this.replacementNamed = '/owner_dashboard',
  });

  @override
  State<OwnerDashboardRedirect> createState() => _OwnerDashboardRedirectState();
}

class _OwnerDashboardRedirectState extends State<OwnerDashboardRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement(widget.replacementNamed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// BUG-004 FIX: Specialized dashboard redirect that preserves business type
/// Routes to appropriate dashboard based on business type parameter
class SpecializedDashboardRedirect extends ConsumerStatefulWidget {
  final String businessType;

  const SpecializedDashboardRedirect({super.key, required this.businessType});

  @override
  ConsumerState<SpecializedDashboardRedirect> createState() =>
      _SpecializedDashboardRedirectState();
}

class _SpecializedDashboardRedirectState
    extends ConsumerState<SpecializedDashboardRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Set the business type in the provider
      final type = _parseBusinessType(widget.businessType);
      ref.read(businessTypeProvider.notifier).setBusinessType(type);

      // Navigate to appropriate dashboard based on type
      String targetRoute;
      switch (type) {
        case BusinessType.restaurant:
          targetRoute = '/restaurant/dashboard';
          break;
        case BusinessType.clinic:
          targetRoute = '/clinic/dashboard';
          break;
        case BusinessType.pharmacy:
          targetRoute = '/pharmacy/dashboard';
          break;
        case BusinessType.decorationCatering:
          targetRoute = '/dc/dashboard';
          break;
        default:
          targetRoute = '/owner_dashboard';
      }

      context.pushReplacement(targetRoute);
    });
  }

  BusinessType _parseBusinessType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return BusinessType.restaurant;
      case 'clinic':
        return BusinessType.clinic;
      case 'pharmacy':
        return BusinessType.pharmacy;
      case 'grocery':
        return BusinessType.grocery;
      case 'hardware':
        return BusinessType.hardware;
      case 'decorationcatering':
      case 'decoration_catering':
      case 'decoration':
      case 'catering':
        return BusinessType.decorationCatering;
      default:
        return BusinessType.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.businessType} dashboard...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
