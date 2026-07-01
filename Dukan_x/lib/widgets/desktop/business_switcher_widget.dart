import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/di/service_locator.dart'; // To use sl<SessionManager>()
import '../../features/dashboard/v2/providers/dashboard_v2_providers.dart';
import '../../providers/tenant_config_provider.dart';

final accessibleBusinessesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    // SM-AUDIT #7: Use DI-registered client instead of orphan instance
    final apiClient = sl<ApiClient>();
    final response = await apiClient.get('/businesses/my-access');
    if (response.statusCode == 200 && response.data != null) {
      if (response.data?['success'] == true && response.data?['data'] != null) {
        final List<dynamic> businesses =
            response.data?['data']?['businesses'] ?? [];
        return businesses.map((b) => b as Map<String, dynamic>).toList();
      }
    }
    return [];
  },
);

class BusinessSwitcherWidget extends ConsumerWidget {
  const BusinessSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionManager = sl<SessionManager>();
    final businessesAsync = ref.watch(accessibleBusinessesProvider);

    return businessesAsync.when(
      data: (businesses) {
        if (businesses.isEmpty || businesses.length == 1) {
          // No need to show switcher if only 1 business is available
          return const SizedBox.shrink();
        }

        final activeBusinessId =
            sessionManager.currentSession.activeBusinessId ??
            businesses.first['id'];

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FuturisticColors.premiumBlue.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: businesses.any((b) => b['id'] == activeBusinessId)
                  ? activeBusinessId
                  : businesses.first['id'],
              icon: const Icon(
                Icons.arrow_drop_down,
                color: FuturisticColors.accent1,
                size: 20,
              ),
              dropdownColor: FuturisticColors.background,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (String? newBusinessId) async {
                if (newBusinessId != null &&
                    newBusinessId != activeBusinessId) {
                  await sessionManager.setActiveBusiness(newBusinessId);
                  // SM-AUDIT #5: Invalidate all data providers on business switch
                  ref.invalidate(dashboardV2SummaryProvider);
                  ref.invalidate(dashboardV2RevenueChartProvider);
                  ref.invalidate(dashboardV2InvoiceDistributionProvider);
                  ref.invalidate(dashboardV2RecentInvoicesProvider);
                  ref.invalidate(dashboardV2CashflowProvider);
                  ref.invalidate(dashboardV2NotificationCountProvider);
                  ref.invalidate(dashboardV2LicenseProvider);
                  ref.invalidate(accessibleBusinessesProvider);
                  ref.invalidate(tenantConfigProvider);
                }
              },
              items: businesses.map<DropdownMenuItem<String>>((business) {
                return DropdownMenuItem<String>(
                  value: business['id'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_center,
                        size: 14,
                        color: FuturisticColors.accent1,
                      ),
                      const SizedBox(width: 8),
                      Text(business['name'] ?? 'Unknown Business'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 120,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
