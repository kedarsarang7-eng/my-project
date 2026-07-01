import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Custom Reports & Analytics Screen
class AcReportsScreen extends ConsumerStatefulWidget {
  const AcReportsScreen({super.key});

  @override
  ConsumerState<AcReportsScreen> createState() => _AcReportsScreenState();
}

class _AcReportsScreenState extends ConsumerState<AcReportsScreen> {
  String _selectedTemplate = 'student_list';
  bool _isGenerating = false;

  final List<Map<String, dynamic>> _templates = [
    {'id': 'student_list', 'name': 'Student List', 'icon': Icons.people},
    {
      'id': 'attendance_summary',
      'name': 'Attendance Summary',
      'icon': Icons.event_available,
    },
    {'id': 'fee_collection', 'name': 'Fee Collection', 'icon': Icons.payments},
    {
      'id': 'admission_conversion',
      'name': 'Admission Conversion',
      'icon': Icons.trending_up,
    },
    {
      'id': 'library_activity',
      'name': 'Library Activity',
      'icon': Icons.library_books,
    },
    {
      'id': 'transport_utilization',
      'name': 'Transport Utilization',
      'icon': Icons.directions_bus,
    },
    {'id': 'exam_results', 'name': 'Exam Results', 'icon': Icons.assessment},
    {
      'id': 'faculty_attendance',
      'name': 'Faculty Attendance',
      'icon': Icons.co_present,
    },
    {'id': 'hostel_occupancy', 'name': 'Hostel Occupancy', 'icon': Icons.bed},
    {
      'id': 'inventory_status',
      'name': 'Inventory Status',
      'icon': Icons.inventory,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Reports & Analytics',
      actions: [
        FilledButton.icon(
          onPressed: () => _showScheduleReportDialog(),
          icon: const Icon(Icons.schedule),
          label: const Text('Schedule'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.history),
          tooltip: 'Report History',
        ),
      ],
      child: Row(
        children: [
          // Left Panel - Templates
          SizedBox(
            width: 280,
            child: Card(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Report Templates',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        final isSelected = _selectedTemplate == template['id'];

                        return ListTile(
                          leading: Icon(
                            template['icon'],
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(template['name']),
                          selected: isSelected,
                          onTap: () => setState(
                            () => _selectedTemplate = template['id'],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Panel - Filters & Preview
          Expanded(
            child: Column(
              children: [
                // Quick Stats
                _buildQuickStats(),
                const SizedBox(height: 16),
                // Report Configuration
                Expanded(child: _buildReportConfig()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.people, color: Colors.blue),
              title: const Text('1,248'),
              subtitle: const Text('Total Students'),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('₹15.2L'),
              subtitle: const Text('Fee Collected'),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.orange),
              title: const Text('85%'),
              subtitle: const Text('Attendance'),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.book, color: Colors.purple),
              title: const Text('3,420'),
              subtitle: const Text('Books Issued'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Title
            Text(
              _templates.firstWhere(
                (t) => t['id'] == _selectedTemplate,
              )['name'],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            // Filters
            const Text(
              'Filters',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Batch/Class',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Class 1', 'Class 2', 'Class 3']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'From Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'To Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Additional Filters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Active Students Only'),
                  selected: true,
                  onSelected: (v) {},
                ),
                FilterChip(
                  label: const Text('Include Contact Info'),
                  selected: false,
                  onSelected: (v) {},
                ),
                FilterChip(
                  label: const Text('Show Fees Due'),
                  selected: false,
                  onSelected: (v) {},
                ),
              ],
            ),
            const Spacer(),
            // Export Format
            const Text(
              'Export Format',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_chart, size: 16),
                      SizedBox(width: 4),
                      Text('Excel'),
                    ],
                  ),
                  selected: true,
                  onSelected: (v) {},
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf, size: 16),
                      SizedBox(width: 4),
                      Text('PDF'),
                    ],
                  ),
                  selected: false,
                  onSelected: (v) {},
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16),
                      SizedBox(width: 4),
                      Text('CSV'),
                    ],
                  ),
                  selected: false,
                  onSelected: (v) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Generate Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : () => _generateReport(),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Report',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateReport() {
    setState(() => _isGenerating = true);

    // Simulate report generation
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isGenerating = false);
      _showReportPreview();
    });
  }

  void _showReportPreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Generated'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              // Preview Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Generated Successfully',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '1,248 records • 156 KB',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Data Preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        title: Text('Student ${index + 1}'),
                        subtitle: Text('Class ${(index % 10) + 1}'),
                        trailing: const Text('Active'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.email),
            label: const Text('Email'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showScheduleReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Report Template',
                  border: OutlineInputBorder(),
                ),
                items: _templates
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: ['Daily', 'Weekly', 'Monthly']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Recipients (comma separated emails)',
                  border: OutlineInputBorder(),
                ),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Report scheduled')));
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}
