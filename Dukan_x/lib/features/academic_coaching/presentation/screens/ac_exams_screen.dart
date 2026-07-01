// ============================================================================
// ACADEMIC COACHING — EXAM & RESULTS MANAGEMENT SCREEN
// ============================================================================
// Modern tabbed interface with exam scheduling, mark entry, and result analysis

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcExamsScreen extends StatefulWidget {
  const AcExamsScreen({super.key});

  @override
  State<AcExamsScreen> createState() => _AcExamsScreenState();
}

class _AcExamsScreenState extends State<AcExamsScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  List<AcExam> _exams = [];
  List<AcBatch> _batches = [];
  List<AcStudent> _students = [];
  bool _isLoading = true;
  String? _error;

  // Selected exam for results entry
  AcExam? _selectedExam;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [exams, batches, students] = await Future.wait([
        _repository.listExams(),
        _repository.listBatches(),
        _repository.listStudents(),
      ]);

      setState(() {
        _exams = exams as List<AcExam>;
        _batches = batches as List<AcBatch>;
        _students = students as List<AcStudent>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4F46E5),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF4F46E5),
            tabs: const [
              Tab(icon: Icon(Icons.assignment), text: 'Exams'),
              Tab(icon: Icon(Icons.edit_note), text: 'Mark Entry'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Results'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildExamsTab(),
                      _buildMarkEntryTab(),
                      _buildResultsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exam Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_exams.length} exams scheduled • ${_exams.where((e) => e.status == 'completed').length} completed',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCreateExamDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule Exam'),
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
      ),
    );
  }

  Widget _buildExamsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _exams.length,
      itemBuilder: (context, index) {
        final exam = _exams[index];
        final isCompleted = exam.status == 'completed';
        final isScheduled = exam.status == 'scheduled';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFDCFCE7)
                            : isScheduled
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : isScheduled
                            ? Icons.schedule
                            : Icons.hourglass_empty,
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : isScheduled
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${exam.type.name.toUpperCase()} • ${exam.date}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF059669).withOpacity(0.1)
                            : isScheduled
                            ? const Color(0xFF4F46E5).withOpacity(0.1)
                            : const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        exam.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? const Color(0xFF059669)
                              : isScheduled
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Batches & Subjects
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Batches',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: exam.batchIds.map((id) {
                              final batch = _batches.firstWhere(
                                (b) => b.id == id,
                                orElse: () => AcBatch(
                                  id: '',
                                  name: 'Unknown',
                                  courseId: '',
                                  maxCapacity: 0,
                                  enrolledCount: 0,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );
                              return Chip(
                                label: Text(batch.name),
                                backgroundColor: const Color(0xFFF1F5F9),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                labelStyle: const TextStyle(fontSize: 11),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subjects',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: exam.subjects
                                .map(
                                  (s) => Chip(
                                    label: Text(
                                      '${s.subjectName ?? s.subjectId} (${s.maxMarks})',
                                    ),
                                    backgroundColor: const Color(0xFFEEF2FF),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                    labelStyle: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isCompleted)
                      TextButton.icon(
                        onPressed: () => _selectExamForResults(exam),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Enter Marks'),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _viewResults(exam),
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('View Results'),
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

  Widget _buildMarkEntryTab() {
    if (_selectedExam == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 64, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'Select an exam from the Exams tab to enter marks',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final examStudents = _students.where((s) {
      return _selectedExam!.batchIds.any(
        (batchId) => s.enrolledBatchIds.contains(batchId) ?? false,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedExam = null),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedExam!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${examStudents.length} students eligible',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _submitResults(),
                    icon: const Icon(Icons.save),
                    label: const Text('Submit All Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.builder(
                itemCount: examStudents.length,
                itemBuilder: (context, index) {
                  final student = examStudents[index];
                  return _buildMarkEntryRow(student);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkEntryRow(AcStudent student) {
    final subjectControllers = <String, TextEditingController>{};

    for (var subject in _selectedExam!.subjects) {
      subjectControllers[subject.subjectId] = TextEditingController();
    }

    return ListTile(
      leading: CircleAvatar(child: Text(student.firstName[0])),
      title: Text(student.fullName),
      subtitle: Text(student.studentId),
      trailing: SizedBox(
        width: 300,
        child: Row(
          children: _selectedExam!.subjects.map((subject) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: subjectControllers[subject.subjectId],
                  decoration: InputDecoration(
                    labelText: subject.subjectName ?? subject.subjectId,
                    hintText: '/${subject.maxMarks}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    final completedExams = _exams
        .where((e) => e.status == 'completed')
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: completedExams.length,
      itemBuilder: (context, index) {
        final exam = completedExams[index];

        return FutureBuilder(
          future: _repository.getExamResults(exam.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final results = snapshot.data!;
            final passRate = results['passPercentage'] ?? 0;
            final avgPercentage = results['averagePercentage'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exam.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${results['totalStudents']} students • ${results['passCount']} passed',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildResultMetric(
                          'Pass Rate',
                          '$passRate%',
                          passRate >= 70
                              ? const Color(0xFF059669)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 24),
                        _buildResultMetric(
                          'Avg Score',
                          '$avgPercentage%',
                          avgPercentage >= 70
                              ? const Color(0xFF059669)
                              : const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Grade Distribution
                    const Text(
                      'Grade Distribution',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildGradeDistribution(
                      results['results'] as List<dynamic>? ?? [],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _downloadResults(exam),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Report'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResultMetric(String label, String value, Color color) {
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildGradeDistribution(List<dynamic> results) {
    final grades = <String, int>{};
    for (var r in results) {
      final grade = r['grade'] as String? ?? 'F';
      grades[grade] = (grades[grade] ?? 0) + 1;
    }

    final gradeColors = {
      'A+': const Color(0xFF059669),
      'A': const Color(0xFF10B981),
      'B+': const Color(0xFF3B82F6),
      'B': const Color(0xFF60A5FA),
      'C': const Color(0xFFF59E0B),
      'D': const Color(0xFFF97316),
      'F': const Color(0xFFDC2626),
    };

    return Wrap(
      spacing: 12,
      children: grades.entries.map((e) {
        return Chip(
          avatar: CircleAvatar(
            backgroundColor: gradeColors[e.key] ?? Colors.grey,
            radius: 10,
          ),
          label: Text('${e.key}: ${e.value}'),
          backgroundColor: (gradeColors[e.key] ?? Colors.grey).withOpacity(0.1),
        );
      }).toList(),
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

  void _showCreateExamDialog() {
    // Create exam dialog — pending feature gate
  }

  void _selectExamForResults(AcExam exam) {
    setState(() {
      _selectedExam = exam;
      _tabController.animateTo(1);
    });
  }

  void _viewResults(AcExam exam) {
    setState(() {
      _selectedExam = exam;
      _tabController.animateTo(2);
    });
  }

  void _submitResults() {
    // Submit all results — pending feature gate
  }

  void _downloadResults(AcExam exam) {
    // Download results report — pending feature gate
  }
}
