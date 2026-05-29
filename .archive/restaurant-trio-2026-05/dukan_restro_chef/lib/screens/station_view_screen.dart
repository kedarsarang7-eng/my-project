import 'package:flutter/material.dart';
import '../models/chef_models.dart';
import '../state/chef_state.dart';

class StationViewScreen extends StatelessWidget {
  final ChefState state;
  const StationViewScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    const stations = ['All', 'Grill', 'Tandoor', 'Cold', 'Dessert'];
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: stations.length,
            itemBuilder: (_, i) {
              final s = stations[i];
              final selected = state.station == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => state.setStation(s),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: state.loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                )
              : state.stationFiltered.isEmpty
              ? const Center(
                  child: Text('No KOT for this station', style: TextStyle(color: Colors.grey)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: state.stationFiltered.length,
                  itemBuilder: (_, i) {
                    final kot = state.stationFiltered[i];
                    return _StationKotCard(kot: kot, state: state);
                  },
                ),
        ),
      ],
    );
  }
}

class _StationKotCard extends StatelessWidget {
  final ChefKot kot;
  final ChefState state;
  const _StationKotCard({required this.kot, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text('KOT ${kot.id.substring(0, 6).toUpperCase()}'),
            subtitle: Text('${kot.tableLabel} · ${kot.ageMinutes}m'),
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
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () => state.advanceItem(kot, item),
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
