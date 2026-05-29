import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class HostelScreen extends ConsumerWidget {
  const HostelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hostelProvider);

    return PageScaffold(
      title: 'Hostel Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(hostelProvider),
        child: async.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120), SizedBox(height: 16), ShimmerBox(height: 200)])),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(hostelProvider)),
          data: (data) {
            final blocks = (data['blocks'] as List?) ?? [];
            final totalRooms = data['totalRooms'] ?? 0;
            final occupiedRooms = data['occupiedRooms'] ?? 0;
            final totalResidents = data['totalResidents'] ?? 0;
            final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms * 100) : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.apartment_rounded, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Hostel Overview', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('$totalResidents residents · ${occupancyRate.toStringAsFixed(0)}% occupancy', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: occupancyRate / 100, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: StatCard(label: 'Total Rooms', value: '$totalRooms', icon: Icons.meeting_room_rounded, color: AppTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Occupied', value: '$occupiedRooms', icon: Icons.bed_rounded, color: AppTheme.success)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Vacant', value: '${totalRooms - occupiedRooms}', icon: Icons.door_front_door_outlined, color: AppTheme.warning)),
                ]),
                if (blocks.isNotEmpty) ...[
                  const SectionHeader(title: 'Hostel Blocks'),
                  ...blocks.map((block) {
                    final b = block as Map<String, dynamic>;
                    final blockOcc = (b['occupiedRooms'] ?? 0) as num;
                    final blockTotal = (b['totalRooms'] ?? 1) as num;
                    final pct = blockTotal > 0 ? blockOcc / blockTotal : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(b['name'] ?? 'Block', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const Spacer(),
                            StatusBadge(label: (b['gender'] ?? 'co-ed').toString().toUpperCase(), color: AppTheme.primary),
                          ]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('$blockOcc / $blockTotal rooms occupied', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary), minHeight: 6)),
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
