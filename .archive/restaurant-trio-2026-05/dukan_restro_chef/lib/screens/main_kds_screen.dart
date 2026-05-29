import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chef_models.dart';
import '../state/chef_state.dart';

class MainKdsScreen extends StatelessWidget {
  final ChefState state;
  const MainKdsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)));
    }
    final list = state.activeKots;
    if (list.isEmpty) {
      return const Center(
        child: Text('No pending KOTs', style: TextStyle(color: Colors.grey)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _KotCard(kot: list[i], state: state),
    );
  }
}

class _KotCard extends StatelessWidget {
  final ChefKot kot;
  final ChefState state;
  const _KotCard({required this.kot, required this.state});

  @override
  Widget build(BuildContext context) {
    final old = kot.ageMinutes > 15;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kot.priority
              ? Colors.redAccent
              : old
              ? Colors.red.withValues(alpha: 0.6)
              : const Color(0xFF2E2E2E),
          width: kot.priority ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'KOT ${kot.id.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${kot.tableLabel} · ${kot.ageMinutes}m'),
            trailing: IconButton(
              icon: const Icon(Icons.done_all, color: Colors.orange),
              tooltip: 'Bulk complete simple items',
              onPressed: () => state.bulkCompleteSimpleItems(kot),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2E2E2E)),
          Expanded(
            child: ListView.builder(
              itemCount: kot.items.length,
              itemBuilder: (_, idx) {
                final item = kot.items[idx];
                return ListTile(
                  dense: true,
                  title: Text('${item.qty}x ${item.name}'),
                  subtitle: Text(item.status),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.block, size: 18, color: Colors.red),
                        tooltip: '86 item',
                        onPressed: () => state.markUnavailable(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 18, color: Colors.green),
                        tooltip: 'Advance status',
                        onPressed: () {
                          SystemSound.play(SystemSoundType.alert);
                          state.advanceItem(kot, item);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
