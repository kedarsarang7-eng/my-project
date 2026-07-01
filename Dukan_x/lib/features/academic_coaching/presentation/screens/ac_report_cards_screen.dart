// ============================================================================
// SCHOOL ERP — REPORT CARDS / MARKSHEET SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcReportCardsScreen extends StatefulWidget {
  const AcReportCardsScreen({super.key});

  @override
  State<AcReportCardsScreen> createState() => _AcReportCardsScreenState();
}

class _AcReportCardsScreenState extends State<AcReportCardsScreen> {
  late AcRepository _repository;

  List<AcReportCard> _reportCards = [];
  List<AcClassRoom> _classes = [];
  bool _isLoading = true;
  String? _selectedClassId;
  String _searchQuery = '';

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.listReportCards(classId: _selectedClassId),
        _repository.listClasses(),
      ]);
      setState(() {
        _reportCards = results[0] as List<AcReportCard>;
        _classes = results[1] as List<AcClassRoom>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<AcReportCard> get _filtered {
    var list = _reportCards;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (r) =>
                r.studentName.toLowerCase().contains(q) ||
                r.studentId.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          _buildStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateReportCardDialog,
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Generate Report Card',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      color: _bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.grading_outlined, color: _teal, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Cards',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${_reportCards.length} report cards generated',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _teal),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search student...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedClassId,
                hint: const Text('All Classes', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Classes'),
                  ),
                  ..._classes.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedClassId = v);
                  _loadData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_reportCards.isEmpty) return const SizedBox.shrink();
    final avgScore = _reportCards.isEmpty
        ? 0.0
        : _reportCards.map((r) => r.percentage).reduce((a, b) => a + b) /
              _reportCards.length;
    final passed = _reportCards.where((r) => r.isPassed).length;
    final distinction = _reportCards.where((r) => r.percentage >= 75).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _statCard(
            'Avg Score',
            '${avgScore.toStringAsFixed(1)}%',
            Icons.percent,
            _teal,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Passed',
            '$passed',
            Icons.check_circle_outline,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Distinction',
            '$distinction',
            Icons.star_outline,
            Colors.amber,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Failed',
            '${_reportCards.length - passed}',
            Icons.cancel_outlined,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: _filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(AcReportCard card) {
    final gradeColor = _gradeColor(card.grade);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: gradeColor.withOpacity(0.15),
                  child: Text(
                    card.grade,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${card.className} · ${card.examName}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${card.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: gradeColor,
                      ),
                    ),
                    Text(
                      '${card.totalMarksObtained}/${card.totalMaxMarks}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSubjectGrid(card),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: card.isPassed
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    card.isPassed ? 'PASSED' : 'FAILED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: card.isPassed
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _downloadReportCard(card),
                  icon: const Icon(
                    Icons.download_outlined,
                    size: 16,
                    color: _teal,
                  ),
                  label: const Text(
                    'Download PDF',
                    style: TextStyle(color: _teal, fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _shareReportCard(card),
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 16,
                    color: Colors.blue,
                  ),
                  label: const Text(
                    'Share',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectGrid(AcReportCard card) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: card.subjects.map((s) {
        final pct = s.maxMarks > 0 ? s.marksObtained / s.maxMarks * 100 : 0;
        final c = pct >= 75
            ? Colors.green
            : pct >= 50
            ? Colors.blue
            : Colors.red;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.subjectName,
                style: TextStyle(fontSize: 10, color: c.withOpacity(0.8)),
              ),
              Text(
                '${s.marksObtained}/${s.maxMarks}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grading_outlined, size: 64, color: _teal.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No report cards yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate report cards after exams are completed',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showGenerateReportCardDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Generate Report Card'),
          ),
        ],
      ),
    );
  }

  void _showGenerateReportCardDialog() {
    String? selectedClassId;
    String? selectedExamId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Generate Report Cards',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select a class and exam to generate report cards for all students.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.class_outlined),
                ),
                items: _classes
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setDs(() => selectedClassId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Exam Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.assignment_outlined),
                ),
                onChanged: (v) => selectedExamId = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedClassId == null) return;
                Navigator.pop(ctx);
                try {
                  await _repository.generateReportCards(
                    classId: selectedClassId!,
                    examName: selectedExamId ?? 'Final Exam',
                  );
                  _loadData();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report cards generated successfully'),
                        backgroundColor: Color(0xFF0D9488),
                      ),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReportCard(AcReportCard card) async {
    try {
      final pdfUrl = await _repository.downloadReportCardPdf(
        reportCardId: card.id,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading report card for ${card.studentName}...'),
            backgroundColor: _teal,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _shareReportCard(AcReportCard card) async {
    try {
      await _repository.shareReportCard(reportCardId: card.id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report card shared to parent of ${card.studentName}',
            ),
            backgroundColor: _teal,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }
}
