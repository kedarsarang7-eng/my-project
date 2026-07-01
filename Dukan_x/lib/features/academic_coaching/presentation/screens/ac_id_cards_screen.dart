// ============================================================================
// ACADEMIC COACHING — ID CARD MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../widgets/ac_debounce_search.dart';
import '../widgets/ac_skeleton_widgets.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcIdCardsScreen extends StatefulWidget {
  const AcIdCardsScreen({super.key});

  @override
  State<AcIdCardsScreen> createState() => _AcIdCardsScreenState();
}

class _AcIdCardsScreenState extends State<AcIdCardsScreen>
    with DebouncedSearchMixin {
  late AcRepository _repository;
  List<AcStudent> _students = [];
  List<AcBatch> _batches = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedBatchId;
  String _searchQuery = '';
  final Set<String> _selectedStudents = {};

  final String _instituteName = 'Academic Coaching Institute';
  final String _instituteAddress = '123 Education Lane, Knowledge City';
  final String _institutePhone = '+91 98765 43210';

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
      final [studentsResponse, batches] = await Future.wait([
        _repository.listStudents(limit: 100),
        _repository.listBatches(),
      ]);

      setState(() {
        _students = (studentsResponse as PaginatedResponse<AcStudent>).items;
        _batches = batches as List<AcBatch>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  List<AcStudent> get _filteredStudents {
    return _students.where((s) {
      // Batch filter
      if (_selectedBatchId != null &&
          !s.enrolledBatchIds.contains(_selectedBatchId)) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = s.fullName.toLowerCase().contains(query);
        final idMatch = s.studentId.toLowerCase().contains(query);
        final phoneMatch = s.phone.toLowerCase().contains(query);
        return nameMatch || idMatch || phoneMatch;
      }

      return true;
    }).toList();
  }

  Future<void> _generateBulkIdCards() async {
    final selected = _students
        .where((s) => _selectedStudents.contains(s.id))
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Generating ID Cards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Generating ${selected.length} ID cards...'),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();

      for (final student in selected) {
        final batchName = _getBatchName(student.enrolledBatchIds.firstOrNull);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => _buildIdCardPage(student, batchName),
          ),
        );
      }

      final bytes = await pdf.save();
      Navigator.pop(context);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ID_Cards_Batch_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String? _getBatchName(String? batchId) {
    if (batchId == null) return null;
    final batch = _batches.firstWhere(
      (b) => b.id == batchId,
      orElse: () => AcBatch(
        id: '',
        name: 'Unknown',
        batchCode: '',
        courseId: '',
        maxCapacity: 0,
        enrolledCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return batch.name;
  }

  pw.Widget _buildIdCardPage(AcStudent student, String? batchName) {
    return pw.Center(
      child: pw.Container(
        width: 85 * PdfPageFormat.mm,
        height: 55 * PdfPageFormat.mm,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#4F46E5'), width: 2),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#4F46E5'),
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(6),
                  topRight: pw.Radius.circular(6),
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  _instituteName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'Photo',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            student.fullName,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'ID: ${student.studentId}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          if (batchName != null) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Batch: $batchName',
                              style: pw.TextStyle(fontSize: 9),
                            ),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Valid Until: 31-03-${DateTime.now().year + 1}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  ? const AcShimmer(child: AcSkeletonTable(rowCount: 8))
                  : _error != null
                  ? _buildError()
                  : _buildStudentsTable(),
            ),
            if (_selectedStudents.isNotEmpty) _buildSelectionBar(),
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
              'ID Card Generator',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate and print student ID cards',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _generateBulkIdCards,
              icon: const Icon(Icons.badge),
              label: Text('Generate (${_selectedStudents.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
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
          Expanded(
            flex: 2,
            child: DebouncedSearchField(
              hintText: 'Search students...',
              onSearch: (query) {
                setState(() => _searchQuery = query);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedBatchId,
              decoration: const InputDecoration(
                labelText: 'Filter by Batch',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Batches')),
                ..._batches.map(
                  (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedBatchId = v),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedBatchId = null;
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTable() {
    final students = _filteredStudents;

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No students found'),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final isSelected = _selectedStudents.contains(student.id);

          return CheckboxListTile(
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedStudents.add(student.id);
                } else {
                  _selectedStudents.remove(student.id);
                }
              });
            },
            title: Text(student.fullName),
            subtitle: Text('${student.studentId} • ${student.phone}'),
            secondary: CircleAvatar(
              child: Text(
                student.fullName.isNotEmpty ? student.fullName[0] : '?',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedStudents.length} students selected',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedStudents.clear()),
            child: const Text('Clear Selection'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _generateBulkIdCards,
            icon: const Icon(Icons.print),
            label: const Text('Generate ID Cards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
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
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'Error loading data'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
