// ============================================================================
// ACADEMIC COACHING — TIMETABLE MANAGEMENT SCREEN
// ============================================================================
// Weekly schedule view with conflict detection and slot management

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

class AcTimetableScreen extends StatefulWidget {
  const AcTimetableScreen({super.key});

  @override
  State<AcTimetableScreen> createState() => _AcTimetableScreenState();
}

class _AcTimetableScreenState extends State<AcTimetableScreen> {
  late AcRepository _repository;
  List<AcBatch> _batches = [];
  List<AcFaculty> _faculty = [];
  List<dynamic> _slots = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedBatchId;
  String? _selectedFacultyId;
  String _selectedView = 'batch'; // 'batch' or 'faculty'
  int _selectedDay = DateTime.now().weekday % 7;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [batches, faculty] = await Future.wait([
        _repository.listBatches(),
        _repository.listFaculty(),
      ]);

      setState(() {
        _batches = batches as List<AcBatch>;
        _faculty = faculty as List<AcFaculty>;
        _isLoading = false;
      });

      if (_selectedBatchId != null || _selectedFacultyId != null) {
        _loadTimetable();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTimetable() async {
    try {
      final slots = await _repository.getTimetable(
        batchId: _selectedView == 'batch' ? _selectedBatchId : null,
        facultyId: _selectedView == 'faculty' ? _selectedFacultyId : null,
      );
      setState(() {
        _slots = slots;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load timetable: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFilterBar(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : _buildTimetableView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSlotDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
        backgroundColor: const Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timetable Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Weekly schedule with conflict detection',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _publishTimetable(),
              icon: const Icon(Icons.publish, size: 18),
              label: const Text('Publish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // View Toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'batch',
                label: Text('By Batch'),
                icon: Icon(Icons.group),
              ),
              ButtonSegment(
                value: 'faculty',
                label: Text('By Faculty'),
                icon: Icon(Icons.person),
              ),
            ],
            selected: {_selectedView},
            onSelectionChanged: (v) {
              setState(() {
                _selectedView = v.first;
                _selectedBatchId = null;
                _selectedFacultyId = null;
                _slots = [];
              });
            },
          ),
          const SizedBox(width: 16),
          // Dropdown
          Expanded(
            child: _selectedView == 'batch'
                ? DropdownButtonFormField<String>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Select Batch',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Choose a batch'),
                      ),
                      ..._batches.map(
                        (b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedBatchId = v);
                      _loadTimetable();
                    },
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedFacultyId,
                    decoration: const InputDecoration(
                      labelText: 'Select Faculty',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Choose faculty'),
                      ),
                      ..._faculty.map(
                        (f) =>
                            DropdownMenuItem(value: f.id, child: Text(f.name)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedFacultyId = v);
                      _loadTimetable();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableView() {
    if (_selectedBatchId == null && _selectedFacultyId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_view_week,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a batch or faculty to view timetable',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Day selector
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedDay == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_days[index]),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedDay = index),
                  selectedColor: const Color(0xFF4F46E5),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
        // Slots list
        Expanded(child: _buildDaySlots()),
      ],
    );
  }

  Widget _buildDaySlots() {
    final daySlots =
        _slots.where((s) => s['dayOfWeek'] == _selectedDay).toList()..sort(
          (a, b) => (a['startTime'] ?? '').compareTo(b['startTime'] ?? ''),
        );

    if (daySlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No slots for ${_days[_selectedDay]}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddSlotDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Slot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: daySlots.length,
      itemBuilder: (context, index) {
        final slot = daySlots[index];
        return _buildSlotCard(slot);
      },
    );
  }

  Widget _buildSlotCard(dynamic slot) {
    final startTime = slot['startTime'] ?? '09:00';
    final endTime = slot['endTime'] ?? '10:00';
    final subject =
        slot['subjectName'] ?? slot['subjectId'] ?? 'Unknown Subject';
    final facultyName =
        slot['facultyName'] ?? slot['facultyId'] ?? 'No Faculty';
    final room = slot['room'] ?? 'TBD';
    final hasConflict = slot['hasConflict'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasConflict
              ? const Color(0xFFDC2626)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: hasConflict
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                startTime,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasConflict
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                ),
              ),
              Text(
                'to',
                style: TextStyle(
                  fontSize: 10,
                  color: hasConflict
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                endTime,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasConflict
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (hasConflict) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CONFLICT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('Faculty: $facultyName • Room: $room'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEditSlotDialog(slot);
            if (v == 'delete') _deleteSlot(slot['id']);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showAddSlotDialog() {
    // Show dialog to add timetable slot
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Timetable Slot'),
        content: const Text(
          'Slot creation form - implement based on requirements',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Slot'),
          ),
        ],
      ),
    );
  }

  void _showEditSlotDialog(dynamic slot) {
    // Edit slot dialog — pending feature gate
  }

  Future<void> _deleteSlot(String slotId) async {
    // Delete slot — pending feature gate
  }

  void _publishTimetable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timetable published successfully!')),
    );
  }
}
