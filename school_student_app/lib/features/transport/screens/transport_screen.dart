import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: 'My Transport',
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(schoolRepoProvider).getMyTransport(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120), SizedBox(height: 16), ShimmerBox(height: 200)]));
          }
          if (snap.hasError) return ErrorState(message: snap.error.toString());
          final data = snap.data ?? {};
          if (data.isEmpty || data['route'] == null) {
            return const EmptyState(message: 'No transport assigned', icon: Icons.directions_bus_outlined);
          }
          final route = data['route'] as Map<String, dynamic>? ?? {};
          final vehicle = data['vehicle'] as Map<String, dynamic>? ?? {};
          final driver = data['driver'] as Map<String, dynamic>? ?? {};
          final stops = (data['stops'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const Icon(Icons.route_rounded, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('My Route', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(route['name'] ?? 'Route', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      Text('Stop: ${data['stopName'] ?? '—'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                  ]),
                ),
                const SectionHeader(title: 'Vehicle Details'),
                Row(children: [
                  Expanded(child: StatCard(label: 'Vehicle No.', value: vehicle['vehicleNo'] ?? '—', icon: Icons.directions_bus_rounded, color: AppTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Capacity', value: '${vehicle['capacity'] ?? '—'}', icon: Icons.people_rounded, color: AppTheme.secondary)),
                ]),
                const SectionHeader(title: 'Driver Info'),
                if (driver.isNotEmpty) InfoTile(
                  icon: Icons.person_rounded,
                  title: driver['name'] ?? 'Driver',
                  subtitle: driver['phone'] ?? '',
                  iconColor: AppTheme.success,
                  trailing: driver['phone'] != null
                      ? IconButton(icon: const Icon(Icons.call, color: AppTheme.success, size: 20), onPressed: () {})
                      : null,
                ),
                const SectionHeader(title: 'Route Stops'),
                ...stops.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _StopTile(index: e.key, stop: e.value as Map<String, dynamic>, isMine: e.value['name'] == data['stopName']),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> stop;
  final bool isMine;
  const _StopTile({required this.index, required this.stop, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isMine ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.divider),
      ),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: isMine ? AppTheme.primary : Colors.grey.shade200, shape: BoxShape.circle),
          child: Center(child: Text('${index + 1}', style: TextStyle(color: isMine ? Colors.white : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(child: Text(stop['name'] ?? '', style: TextStyle(fontWeight: isMine ? FontWeight.w600 : FontWeight.w400))),
        if (stop['arrivalTime'] != null) Text(stop['arrivalTime'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (isMine) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 16)),
      ]),
    );
  }
}
