import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ac_repository.dart';
import '../../data/providers/ac_providers.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Lesson Plans Screen
/// Teacher lesson planning with approval workflow
class AcLessonPlansScreen extends ConsumerStatefulWidget {
  const AcLessonPlansScreen({super.key});

  @override
  ConsumerState<AcLessonPlansScreen> createState() =>
      _AcLessonPlansScreenState();
}

class _AcLessonPlansScreenState extends ConsumerState<AcLessonPlansScreen> {
  String _selectedFilter = 'all';
  String _selectedBatch = '';
  List<Map<String, dynamic>> _lessonPlans = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLessonPlans();
  }

  Future<void> _loadLessonPlans() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(acRepositoryProvider);
      final data = await repo.getLessonPlans(
        batchId: _selectedBatch.isNotEmpty ? _selectedBatch : null,
        status: _selectedFilter != 'all' ? _selectedFilter : null,
      );
      setState(() {
        _lessonPlans = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Lesson Plans',
      actions: [
        FilledButton.icon(
          onPressed: () => _showCreateLessonPlanDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Create Plan'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadLessonPlans,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          // Filters
          _buildFilters(),
          const SizedBox(height: 16),
          // Lesson Plans List
          Expanded(child: _buildLessonPlansList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'draft', label: Text('Draft')),
                ButtonSegment(value: 'submitted', label: Text('Submitted')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (set) {
                setState(() => _selectedFilter = set.first);
                _loadLessonPlans();
              },
            ),
            const SizedBox(width: 16),
            // Calendar View Toggle
            OutlinedButton.icon(
              onPressed: () => _showCalendarView(),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Calendar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonPlansList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lessonPlans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No lesson plans found'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _lessonPlans.length,
      itemBuilder: (context, index) {
        final plan = _lessonPlans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _buildStatusIcon(plan['status']),
            title: Text('${plan['subject']} - ${plan['topic']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${plan['batchName'] ?? 'N/A'} • ${plan['date']}'),
                Text('Duration: ${plan['durationMinutes']} mins'),
                if (plan['objectives'] != null)
                  Text('Objectives: ${(plan['objectives'] as List).length}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleAction(value, plan),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (plan['status'] == 'submitted')
                  const PopupMenuItem(value: 'approve', child: Text('Approve')),
                if (plan['status'] == 'draft')
                  const PopupMenuItem(
                    value: 'submit',
                    child: Text('Submit for Approval'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(String? status) {
    final icons = {
      'draft': Icons.edit_note,
      'submitted': Icons.pending,
      'approved': Icons.check_circle,
    };
    final colors = {
      'draft': Colors.grey,
      'submitted': Colors.orange,
      'approved': Colors.green,
    };

    return CircleAvatar(
      backgroundColor: (colors[status] ?? Colors.grey).withOpacity(0.2),
      child: Icon(
        icons[status] ?? Icons.note,
        color: colors[status] ?? Colors.grey,
      ),
    );
  }

  void _showCreateLessonPlanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Lesson Plan'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Subject')),
              TextField(decoration: InputDecoration(labelText: 'Topic')),
              TextField(decoration: InputDecoration(labelText: 'Date')),
              TextField(
                decoration: InputDecoration(labelText: 'Duration (minutes)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Create logic
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCalendarView() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Plan Calendar'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: CalendarDatePicker(
            initialDate: DateTime.now(),
            firstDate: DateTime(2024),
            lastDate: DateTime(2026),
            onDateChanged: (date) {
              // Show plans for selected date
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, Map<String, dynamic> plan) async {
    switch (action) {
      case 'view':
        _viewLessonPlan(plan);
        break;
      case 'edit':
        _editLessonPlan(plan);
        break;
      case 'approve':
        await _approveLessonPlan(plan['id']);
        break;
      case 'submit':
        await _submitLessonPlan(plan['id']);
        break;
      case 'delete':
        await _deleteLessonPlan(plan['id']);
        break;
    }
  }

  void _viewLessonPlan(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan['topic'] ?? 'Lesson Plan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Subject: ${plan['subject']}'),
              Text('Date: ${plan['date']}'),
              Text('Duration: ${plan['durationMinutes']} minutes'),
              const SizedBox(height: 16),
              const Text(
                'Objectives:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(plan['objectives'] as List? ?? []).map(
                (obj) => Text('• $obj'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Teaching Methods:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(plan['teachingMethods'] ?? 'N/A'),
              const SizedBox(height: 16),
              const Text(
                'Board Work:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(plan['boardWork'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editLessonPlan(Map<String, dynamic> plan) {
    // Edit dialog
  }

  Future<void> _approveLessonPlan(String id) async {
    try {
      final repo = ref.read(acRepositoryProvider);
      await repo.approveLessonPlan(id, approved: true);
      _loadLessonPlans();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submitLessonPlan(String id) async {
    try {
      final repo = ref.read(acRepositoryProvider);
      await repo.updateLessonPlanStatus(id, status: 'submitted');
      _loadLessonPlans();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteLessonPlan(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson Plan?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(acRepositoryProvider);
        await repo.deleteLessonPlan(id);
        _loadLessonPlans();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
