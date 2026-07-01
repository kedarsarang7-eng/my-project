// ============================================================================
// ACADEMIC COACHING — CERTIFICATE GENERATOR SCREEN
// ============================================================================
// Modern certificate generation with templates and bulk operations

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcCertificateGeneratorScreen extends StatefulWidget {
  const AcCertificateGeneratorScreen({super.key});

  @override
  State<AcCertificateGeneratorScreen> createState() =>
      _AcCertificateGeneratorScreenState();
}

class _AcCertificateGeneratorScreenState
    extends State<AcCertificateGeneratorScreen> {
  late AcRepository _repository;
  List<dynamic> _certificates = [];
  List<AcStudent> _students = [];
  List<AcCourse> _courses = [];
  bool _isLoading = true;
  String? _error;
  bool _isGenerating = false;

  // Selection state
  String? _selectedStudentId;
  String? _selectedCourseId;
  String _selectedType = 'course_completion';

  final List<String> _certificateTypes = [
    'course_completion',
    'achievement',
    'attendance',
    'ranking',
    'transfer',
  ];

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
      final results = await Future.wait([
        _repository.listCertificates(),
        _repository.listStudents(),
        _repository.listCourses(),
      ]);

      setState(() {
        _certificates = results[0] as List<Map<String, dynamic>>;
        _students = (results[1] as PaginatedResponse<AcStudent>).items;
        _courses = results[2] as List<AcCourse>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateCertificate() async {
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await _repository.generateCertificate(
        studentId: _selectedStudentId!,
        type: _selectedType,
        metadata: _selectedCourseId != null
            ? {'courseId': _selectedCourseId}
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Certificate ${result['certificateNumber']} generated successfully!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        setState(() => _isGenerating = false);
        _loadData(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isGenerating = false);
      }
    }
  }

  String _getCertificateTypeLabel(String type) {
    switch (type) {
      case 'course_completion':
        return 'Course Completion';
      case 'achievement':
        return 'Achievement';
      case 'attendance':
        return 'Attendance';
      case 'ranking':
        return 'Ranking';
      case 'transfer':
        return 'Transfer';
      default:
        return type;
    }
  }

  IconData _getCertificateTypeIcon(String type) {
    switch (type) {
      case 'course_completion':
        return Icons.school;
      case 'achievement':
        return Icons.emoji_events;
      case 'attendance':
        return Icons.fact_check;
      case 'ranking':
        return Icons.military_tech;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.card_membership;
    }
  }

  Color _getCertificateTypeColor(String type) {
    switch (type) {
      case 'course_completion':
        return const Color(0xFF4F46E5);
      case 'achievement':
        return const Color(0xFFF59E0B);
      case 'attendance':
        return const Color(0xFF059669);
      case 'ranking':
        return const Color(0xFFDC2626);
      case 'transfer':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildGeneratorPanel()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildCertificatesList()),
                      ],
                    ),
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
              'Certificate Generator',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_certificates.length} certificates generated',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.description, size: 18),
              label: const Text('Manage Templates'),
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

  Widget _buildGeneratorPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Certificate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Student Selection
          DropdownButtonFormField<String>(
            value: _selectedStudentId,
            decoration: const InputDecoration(
              labelText: 'Select Student *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Choose a student'),
              ),
              ..._students.map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.fullName} (${s.studentId})'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedStudentId = v),
          ),
          const SizedBox(height: 16),

          // Certificate Type
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Certificate Type *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.card_membership),
            ),
            items: _certificateTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(
                          _getCertificateTypeIcon(type),
                          size: 18,
                          color: _getCertificateTypeColor(type),
                        ),
                        const SizedBox(width: 8),
                        Text(_getCertificateTypeLabel(type)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 16),

          // Course Selection (Optional)
          if (_selectedType == 'course_completion')
            DropdownButtonFormField<String>(
              value: _selectedCourseId,
              decoration: const InputDecoration(
                labelText: 'Select Course (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Auto-detect from enrollment'),
                ),
                ..._courses.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCourseId = v),
            ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateCertificate,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.card_giftcard),
              label: Text(
                _isGenerating ? 'Generating...' : 'Generate Certificate',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.batch_prediction),
              label: const Text('Bulk Generate'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Generated Certificates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _certificates.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _certificates.length,
                    itemBuilder: (context, index) {
                      final cert = _certificates[index];
                      return _buildCertificateCard(cert);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(dynamic cert) {
    final type = cert['type'] as String? ?? 'custom';
    final status = cert['status'] as String? ?? 'issued';
    final isReady = cert['downloadUrl'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCertificateTypeColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getCertificateTypeIcon(type),
            color: _getCertificateTypeColor(type),
          ),
        ),
        title: Text(
          cert['studentName'] ?? 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_getCertificateTypeLabel(type)} • ${cert['certificateNumber'] ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isReady
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isReady ? 'READY' : 'GENERATING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isReady
                          ? const Color(0xFF059669)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Issued: ${cert['issueDate'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReady)
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF4F46E5)),
                onPressed: () => _downloadCertificate(cert['id']),
                tooltip: 'Download',
              ),
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF64748B)),
              onPressed: () {},
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_membership, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No certificates generated yet',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Generate First Certificate'),
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
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Future<void> _downloadCertificate(String certificateId) async {
    try {
      final result = await _repository.downloadCertificate(certificateId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download URL: ${result['downloadUrl']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
