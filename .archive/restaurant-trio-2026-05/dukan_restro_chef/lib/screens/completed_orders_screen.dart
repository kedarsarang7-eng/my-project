import 'package:flutter/material.dart';
import '../state/chef_state.dart';

class CompletedOrdersScreen extends StatefulWidget {
  final ChefState state;
  const CompletedOrdersScreen({super.key, required this.state});

  @override
  State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = widget.state.completedKots.where((k) {
      if (q.isEmpty) return true;
      return k.id.toLowerCase().contains(q) || k.tableLabel.toLowerCase().contains(q);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search by KOT or table',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('No completed KOTs', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final k = list[i];
                    return ListTile(
                      title: Text('KOT ${k.id.substring(0, 6).toUpperCase()}'),
                      subtitle: Text('${k.tableLabel} · ${k.items.length} items'),
                      trailing: Text('${k.ageMinutes}m'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
