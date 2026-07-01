import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Leave Management Screen
class AcLeaveScreen extends ConsumerStatefulWidget {
  const AcLeaveScreen({super.key});

  @override
  ConsumerState<AcLeaveScreen> createState() => _AcLeaveScreenState();
}

class _AcLeaveScreenState extends ConsumerState<AcLeaveScreen> {
  String _selectedTab = 'pending';
  List<Map<String, dynamic>> _leaves = [];

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Leave Management',
      actions: [
        FilledButton.icon(
          onPressed: () => _showApplyLeaveDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Apply Leave'),
        ),
      ],
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ButtonSegment(value: 'all', label: Text('All')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) =>
                setState(() => _selectedTab = set.first),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildLeaveList()),
        ],
      ),
    );
  }

  Widget _buildLeaveList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTypeColor('sick').withOpacity(0.2),
              child: Icon(Icons.person, color: _getTypeColor('sick')),
            ),
            title: const Text('John Doe'),
            subtitle: const Text('Sick Leave • Dec 15-17, 2024'),
            trailing: _buildStatusChip('pending'),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    final colors = {
      'pending': Colors.orange,
      'approved': Colors.green,
      'rejected': Colors.red,
    };

    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: colors[status]?.withOpacity(0.2),
      side: BorderSide.none,
    );
  }

  Color _getTypeColor(String type) {
    final colors = {
      'sick': Colors.red,
      'casual': Colors.blue,
      'emergency': Colors.orange,
    };
    return colors[type] ?? Colors.grey;
  }

  void _showApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Leave'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Leave Type')),
            TextField(decoration: InputDecoration(labelText: 'From Date')),
            TextField(decoration: InputDecoration(labelText: 'To Date')),
            TextField(decoration: InputDecoration(labelText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
