import 'package:flutter/material.dart';
import '../state/chef_state.dart';

class ChefDashboardScreen extends StatelessWidget {
  final ChefState state;
  const ChefDashboardScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.activeKots;
    final done = state.completedKots;
    final totalItems = active.fold<int>(0, (s, k) => s + k.items.length);
    final completedItems = done.fold<int>(0, (s, k) => s + k.items.length);
    final avgCookMins = done.isEmpty
        ? 0.0
        : done.map((k) => k.ageMinutes).reduce((a, b) => a + b) / done.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _metric('Active KOTs', '${active.length}', Icons.kitchen),
          _metric('Completed KOTs', '${done.length}', Icons.done_all),
          _metric('Items in Queue', '$totalItems', Icons.restaurant_menu),
          _metric('Items Completed', '$completedItems', Icons.check_circle),
          _metric('Avg Cook Time', '${avgCookMins.toStringAsFixed(1)}m', Icons.timer),
          _metric('Rush Load', '${(active.length * 12).clamp(0, 100)}%', Icons.bolt),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFEA580C)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
