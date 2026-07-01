import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Hostel Management Screen
class AcHostelScreen extends ConsumerStatefulWidget {
  const AcHostelScreen({super.key});

  @override
  ConsumerState<AcHostelScreen> createState() => _AcHostelScreenState();
}

class _AcHostelScreenState extends ConsumerState<AcHostelScreen> {
  String _selectedView = 'hostels';

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Hostel Management',
      actions: [
        FilledButton.icon(
          onPressed: () => _showAllocateDialog(),
          icon: const Icon(Icons.person_add),
          label: const Text('Allocate Student'),
        ),
      ],
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'hostels', label: Text('Hostels')),
              ButtonSegment(value: 'rooms', label: Text('Rooms')),
              ButtonSegment(value: 'allocations', label: Text('Allocations')),
            ],
            selected: {_selectedView},
            onSelectionChanged: (set) =>
                setState(() => _selectedView = set.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedView == 'hostels'
                ? _buildHostelsView()
                : _selectedView == 'rooms'
                ? _buildRoomsView()
                : _buildAllocationsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelsView() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildHostelCard('Boys Hostel A', 120, 45),
        _buildHostelCard('Girls Hostel B', 100, 32),
        _buildHostelCard('Staff Quarters', 20, 15),
      ],
    );
  }

  Widget _buildHostelCard(String name, int total, int occupied) {
    final available = total - occupied;
    final occupancy = (occupied / total * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', total.toString(), Colors.blue),
                _buildStat('Occupied', occupied.toString(), Colors.orange),
                _buildStat('Available', available.toString(), Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: occupied / total,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            Text(
              '$occupancy% Occupied',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildRoomsView() {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        final room = index + 101;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index % 3 == 0
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              child: Icon(
                Icons.bed,
                color: index % 3 == 0 ? Colors.green : Colors.orange,
              ),
            ),
            title: Text('Room $room'),
            subtitle: Text(
              'Floor ${(room ~/ 100)} • ${index % 3 == 0 ? '2 Beds Available' : '1 Bed Available'}',
            ),
            trailing: Chip(
              label: Text(index % 3 == 0 ? 'Available' : 'Partial'),
              backgroundColor: index % 3 == 0
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllocationsView() {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('Student ${index + 1}'),
            subtitle: const Text('Room 101 • Bed 1'),
            trailing: const Chip(label: Text('Active')),
          ),
        );
      },
    );
  }

  void _showAllocateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate Student'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Student')),
            TextField(decoration: InputDecoration(labelText: 'Hostel')),
            TextField(decoration: InputDecoration(labelText: 'Room')),
            TextField(decoration: InputDecoration(labelText: 'Bed Number')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
  }
}
