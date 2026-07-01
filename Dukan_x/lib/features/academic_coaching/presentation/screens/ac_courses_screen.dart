// ============================================================================
// ACADEMIC COACHING — COURSE MANAGEMENT SCREEN
// ============================================================================
// Modern card layout with subject builder, fee structure, and course stats

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

class AcCoursesScreen extends StatefulWidget {
  const AcCoursesScreen({super.key});

  @override
  State<AcCoursesScreen> createState() => _AcCoursesScreenState();
}

class _AcCoursesScreenState extends State<AcCoursesScreen> {
  late AcRepository _repository;
  List<AcCourse> _courses = [];
  List<AcBatch> _batches = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';

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
      final [courses, batches] = await Future.wait([
        _repository.listCourses(),
        _repository.listBatches(),
      ]);

      setState(() {
        _courses = courses as List<AcCourse>;
        _batches = batches as List<AcBatch>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load courses: $e';
        _isLoading = false;
      });
    }
  }

  List<AcCourse> get _filteredCourses {
    if (_searchQuery.isEmpty) return _courses;
    return _courses.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(query) ||
          (c.targetExam?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int _getBatchCountForCourse(String courseId) {
    return _batches.where((b) => b.courseId == courseId).length;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : _buildCoursesList(fmt),
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
              'Course Catalog',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_courses.length} courses • Manage subjects and fee structure',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showCreateCourseDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Course'),
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

  Widget _buildSearchBar() {
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
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search courses by name or target exam...',
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
    );
  }

  Widget _buildCoursesList(NumberFormat fmt) {
    return ListView.builder(
      itemCount: _filteredCourses.length,
      itemBuilder: (context, index) {
        final course = _filteredCourses[index];
        final batchCount = _getBatchCountForCourse(course.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 28,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Course Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (course.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                course.description!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (course.targetExam != null)
                                _buildTag(
                                  course.targetExam!,
                                  const Color(0xFF059669),
                                ),
                              if (course.duration != null) ...[
                                const SizedBox(width: 8),
                                _buildTag(
                                  '${course.duration!['value']} ${course.duration!['unit']}',
                                  const Color(0xFF4F46E5),
                                ),
                              ],
                              const SizedBox(width: 8),
                              _buildTag(
                                '$batchCount ${batchCount == 1 ? 'batch' : 'batches'}',
                                const Color(0xFFF59E0B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Fee Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Fee',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF059669).withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fmt.format(course.totalFee),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                // Subjects Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subjects',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: course.subjects
                                .map(
                                  (subject) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.book_outlined,
                                          size: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          subject.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Fee Breakdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fee Breakdown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFeeRow(
                            'Tuition Fee',
                            course.totalFee -
                                course.materialFee -
                                course.admissionFee,
                          ),
                          _buildFeeRow('Material Fee', course.materialFee),
                          _buildFeeRow('Admission Fee', course.admissionFee),
                          const Divider(),
                          _buildFeeRow('Total', course.totalFee, isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editCourse(course),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _duplicateCourse(course),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Duplicate'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _createBatchForCourse(course),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Batch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, double amount, {bool isTotal = false}) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            fmt.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFF059669)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
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

  void _showCreateCourseDialog() {
    // Create course dialog — pending feature gate
  }

  void _editCourse(AcCourse course) {
    // Edit course dialog — pending feature gate
  }

  void _duplicateCourse(AcCourse course) {
    // Duplicate course — pending feature gate
  }

  void _createBatchForCourse(AcCourse course) {
    // Navigate to batch creation with pre-selected course — pending feature gate
  }
}
