import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ac_repository.dart';
import '../../data/providers/ac_providers.dart';
import '../widgets/ac_screen_wrapper.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Homework & Assignments Screen
class AcHomeworkScreen extends ConsumerStatefulWidget {
  const AcHomeworkScreen({super.key});

  @override
  ConsumerState<AcHomeworkScreen> createState() => _AcHomeworkScreenState();
}

class _AcHomeworkScreenState extends ConsumerState<AcHomeworkScreen> {
  String _selectedTab = 'assignments';
  List<Map<String, dynamic>> _homework = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(acRepositoryProvider);
      final data = await repo.getHomework();
      setState(() {
        _homework = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Homework & Assignments',
      actions: [
        FilledButton.icon(
          onPressed: () => _showCreateHomeworkDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Assign'),
        ),
      ],
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'assignments', label: Text('Assignments')),
                ButtonSegment(value: 'submissions', label: Text('Submissions')),
                ButtonSegment(value: 'grading', label: Text('Grading')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (set) =>
                  setState(() => _selectedTab = set.first),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedTab == 'assignments'
                ? _buildAssignmentsList()
                : _selectedTab == 'submissions'
                ? _buildSubmissionsList()
                : _buildGradingList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    if (_homework.isEmpty) {
      return const Center(child: Text('No assignments'));
    }

    return ListView.builder(
      itemCount: _homework.length,
      itemBuilder: (context, index) {
        final hw = _homework[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.assignment),
            title: Text(hw['title'] ?? 'Untitled'),
            subtitle: Text('Due: ${hw['dueDate']} • ${hw['subject']}'),
            trailing: Chip(
              label: Text(hw['status'] ?? 'active'),
              backgroundColor: _getStatusColor(hw['status']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionsList() {
    return const Center(child: Text('Submissions view'));
  }

  Widget _buildGradingList() {
    return const Center(child: Text('Grading view'));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green.shade100;
      case 'closed':
        return Colors.grey.shade100;
      default:
        return Colors.blue.shade100;
    }
  }

  void _showCreateHomeworkDialog() {
    // Create homework dialog
  }
}
