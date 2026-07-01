// ============================================================================
// ACADEMIC COACHING — BATCH MANAGEMENT SCREEN
// ============================================================================
// Modern card-based layout with schedule builder, seat availability, and stats

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcBatchesScreen extends StatefulWidget {
  const AcBatchesScreen({super.key});

  @override
  State<AcBatchesScreen> createState() => _AcBatchesScreenState();
}

class _AcBatchesScreenState extends State<AcBatchesScreen> {
  late AcRepository _repository;
  List<AcBatch> _batches = [];
  List<AcCourse> _courses = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  BatchStatus? _selectedStatus;

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
      final [batches, courses] = await Future.wait([
        _repository.listBatches(),
        _repository.listCourses(),
      ]);

      setState(() {
        _batches = batches as List<AcBatch>;
        _courses = courses as List<AcCourse>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load batches: $e';
        _isLoading = false;
      });
    }
  }

  List<AcBatch> get _filteredBatches {
    return _batches.where((b) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!b.name.toLowerCase().contains(query) &&
            !(b.batchCode?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      if (_selectedStatus != null && b.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  Map<String, String> get _courseNameMap {
    return Map.fromEntries(_courses.map((c) => MapEntry(c.id, c.name)));
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
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : _buildBatchesGrid(),
            ),
          ],
        ),
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
              'Batch Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_batches.length} total batches • ${_batches.where((b) => b.status == BatchStatus.active).length} active',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showCreateBatchDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search batches...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<BatchStatus?>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Status')),
                ...BatchStatus.values.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name.toUpperCase()),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _filteredBatches.length,
      itemBuilder: (context, index) {
        final batch = _filteredBatches[index];
        final courseName = _courseNameMap[batch.courseId] ?? 'Unknown Course';
        final occupancyRate = batch.maxCapacity > 0
            ? (batch.enrolledCount / batch.maxCapacity)
            : 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            batch.batchCode ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: batch.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        batch.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: batch.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Course
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    courseName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    _buildStatBox(
                      icon: Icons.people,
                      label: 'Students',
                      value: '${batch.enrolledCount}/${batch.maxCapacity}',
                      color: const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 12),
                    _buildStatBox(
                      icon: Icons.calendar_today,
                      label: 'Schedule',
                      value: '${batch.schedule.length} days',
                      color: const Color(0xFF059669),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Occupancy Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Occupancy',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${(occupancyRate * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: occupancyRate >= 0.9
                                ? const Color(0xFFDC2626)
                                : occupancyRate >= 0.7
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: occupancyRate,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          occupancyRate >= 0.9
                              ? const Color(0xFFDC2626)
                              : occupancyRate >= 0.7
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewBatchDetails(batch),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _editBatch(batch),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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

  void _showCreateBatchDialog() {
    showDialog(
      context: context,
      builder: (context) => _BatchFormDialog(
        courses: _courses,
        onSave: (data) async {
          try {
            await _repository.createBatch(data);
            _loadData();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Batch created successfully!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        },
      ),
    );
  }

  void _viewBatchDetails(AcBatch batch) {
    // Navigate to batch detail — pending feature gate
  }

  void _editBatch(AcBatch batch) {
    // Edit dialog — pending feature gate
  }
}

// ============================================================================
// BATCH FORM DIALOG
// ============================================================================

class _BatchFormDialog extends StatefulWidget {
  final List<AcCourse> courses;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const _BatchFormDialog({
    required this.courses,
    this.initialData, // ignore: unused_element_parameter — retained for the edit-batch flow (see _editBatch TODO); initState reads it
    required this.onSave,
  });

  @override
  State<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '30');
  String? _selectedCourseId;
  BatchType _batchType = BatchType.regular;
  final List<AcScheduleSlot> _schedule = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'] ?? '';
      _codeCtrl.text = widget.initialData!['batchCode'] ?? '';
      _capacityCtrl.text = (widget.initialData!['maxCapacity'] ?? 30)
          .toString();
      _selectedCourseId = widget.initialData!['courseId'];
    }
  }

  void _addScheduleSlot() {
    setState(() {
      _schedule.add(
        AcScheduleSlot(dayOfWeek: 1, startTime: '09:00', endTime: '11:00'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialData == null ? 'Create New Batch' : 'Edit Batch',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),
              // Name & Code
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch Name *',
                        hintText: 'e.g., Morning Batch A',
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch Code',
                        hintText: 'Auto-generated if empty',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Course & Capacity
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCourseId,
                      decoration: const InputDecoration(labelText: 'Course *'),
                      items: widget.courses
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCourseId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Max Capacity *',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<BatchType>(
                      value: _batchType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: BatchType.values
                          .map(
                            (t) =>
                                DropdownMenuItem(value: t, child: Text(t.name)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _batchType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Schedule Builder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Schedule',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: _addScheduleSlot,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Slot'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_schedule.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No schedule slots added yet',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ..._schedule.asMap().entries.map(
                  (e) => _buildScheduleSlot(e.key, e.value),
                ),
              const SizedBox(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave({
                          'name': _nameCtrl.text,
                          'batchCode': _codeCtrl.text.isEmpty
                              ? null
                              : _codeCtrl.text,
                          'courseId': _selectedCourseId,
                          'maxCapacity': int.parse(_capacityCtrl.text),
                          'batchType': _batchType.name,
                          'schedule': _schedule.map((s) => s.toJson()).toList(),
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Batch'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSlot(int index, AcScheduleSlot slot) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: slot.dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day'),
              items: days
                  .asMap()
                  .entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key + 1,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _schedule[index] = AcScheduleSlot(
                  dayOfWeek: v ?? 1,
                  startTime: slot.startTime,
                  endTime: slot.endTime,
                  subjectId: slot.subjectId,
                  subjectName: slot.subjectName,
                  facultyId: slot.facultyId,
                  facultyName: slot.facultyName,
                  roomNo: slot.roomNo,
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: slot.startTime,
              decoration: const InputDecoration(labelText: 'Start Time'),
              onChanged: (v) => setState(() {
                _schedule[index] = AcScheduleSlot(
                  dayOfWeek: slot.dayOfWeek,
                  startTime: v,
                  endTime: slot.endTime,
                  subjectId: slot.subjectId,
                  subjectName: slot.subjectName,
                  facultyId: slot.facultyId,
                  facultyName: slot.facultyName,
                  roomNo: slot.roomNo,
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: slot.endTime,
              decoration: const InputDecoration(labelText: 'End Time'),
              onChanged: (v) => setState(() {
                _schedule[index] = AcScheduleSlot(
                  dayOfWeek: slot.dayOfWeek,
                  startTime: slot.startTime,
                  endTime: v,
                  subjectId: slot.subjectId,
                  subjectName: slot.subjectName,
                  facultyId: slot.facultyId,
                  facultyName: slot.facultyName,
                  roomNo: slot.roomNo,
                );
              }),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => setState(() => _schedule.removeAt(index)),
          ),
        ],
      ),
    );
  }
}
