import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transportProvider);

    return PageScaffold(
      title: 'Transport Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(transportProvider),
        child: async.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120), SizedBox(height: 16), ShimmerBox(height: 200)])),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(transportProvider)),
          data: (data) {
            final routes = (data['routes'] as List?) ?? [];
            final vehicles = (data['vehicles'] as List?) ?? [];
            final totalStudents = data['totalStudents'] ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: StatCard(label: 'Total Routes', value: '${routes.length}', icon: Icons.route_rounded, color: AppTheme.success)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Vehicles', value: '${vehicles.length}', icon: Icons.directions_bus_rounded, color: AppTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Students', value: '$totalStudents', icon: Icons.people_rounded, color: AppTheme.secondary)),
                ]),
                const SectionHeader(title: 'Routes'),
                ...routes.map((r) {
                  final route = r as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.route_rounded, color: AppTheme.success, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(route['name'] ?? 'Route', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${route['stopCount'] ?? 0} stops · ${route['studentCount'] ?? 0} students', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ])),
                        Text(route['vehicleNo'] ?? '—', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ]),
                    ),
                  );
                }),
                if (vehicles.isNotEmpty) ...[
                  const SectionHeader(title: 'Vehicles'),
                  ...vehicles.map((v) {
                    final vehicle = v as Map<String, dynamic>;
                    final status = (vehicle['status'] ?? 'active').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                        child: Row(children: [
                          const Icon(Icons.directions_bus_rounded, color: AppTheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(vehicle['vehicleNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Capacity: ${vehicle['capacity'] ?? '—'} · Driver: ${vehicle['driverName'] ?? '—'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ])),
                          StatusBadge(label: status.toUpperCase(), color: status == 'active' ? AppTheme.success : AppTheme.error),
                        ]),
                      ),
                    );
                  }),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }
}
