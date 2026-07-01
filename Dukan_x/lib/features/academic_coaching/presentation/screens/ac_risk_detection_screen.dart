// ============================================================================
// ACADEMIC COACHING — AI RISK DETECTION DASHBOARD
// ============================================================================
// Modern analytics dashboard with risk scoring, alerts, and intervention tools

import 'package:flutter/material.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcRiskDetectionScreen extends StatefulWidget {
  const AcRiskDetectionScreen({super.key});

  @override
  State<AcRiskDetectionScreen> createState() => _AcRiskDetectionScreenState();
}

class _AcRiskDetectionScreenState extends State<AcRiskDetectionScreen> {
  late AcRepository _repository;
  Map<String, dynamic> _riskData = {};
  List<dynamic> _atRiskStudents = [];
  bool _isLoading = true;
  String? _error;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadRiskData();
  }

  Future<void> _loadRiskData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getAtRiskStudents();
      setState(() {
        _riskData = data;
        _atRiskStudents = data['students'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load risk data: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredStudents {
    if (_selectedFilter == 'all') return _atRiskStudents;
    return _atRiskStudents
        .where((s) => s['riskLevel'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _riskData['summary'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _buildError()
            else ...[
              _buildRiskSummaryCards(summary),
              const SizedBox(height: 24),
              _buildFilterTabs(),
              const SizedBox(height: 16),
              Expanded(child: _buildRiskList()),
            ],
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
              'Student Risk Detection',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI-powered analytics to identify at-risk students',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loadRiskData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Analysis'),
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
              onPressed: () => _sendBulkAlerts(),
              icon: const Icon(Icons.notification_important, size: 18),
              label: const Text('Send Alerts'),
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

  Widget _buildRiskSummaryCards(Map<String, dynamic> summary) {
    return Row(
      children: [
        _buildRiskCard(
          'Critical Risk',
          summary['critical'] ?? 0,
          const Color(0xFFDC2626),
          Icons.warning_amber,
        ),
        const SizedBox(width: 16),
        _buildRiskCard(
          'High Risk',
          summary['high'] ?? 0,
          const Color(0xFFF59E0B),
          Icons.trending_down,
        ),
        const SizedBox(width: 16),
        _buildRiskCard(
          'Medium Risk',
          summary['medium'] ?? 0,
          const Color(0xFF4F46E5),
          Icons.remove_circle_outline,
        ),
        const SizedBox(width: 16),
        _buildRiskCard(
          'Low Risk',
          summary['low'] ?? 0,
          const Color(0xFF059669),
          Icons.info_outline,
        ),
      ],
    );
  }

  Widget _buildRiskCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'All Students'},
      {'key': 'critical', 'label': 'Critical'},
      {'key': 'high', 'label': 'High'},
      {'key': 'medium', 'label': 'Medium'},
      {'key': 'low', 'label': 'Low'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = f['key']!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  f['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRiskList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: const Color(0xFF059669).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No at-risk students found!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All students are performing well',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildStudentRiskCard(student);
      },
    );
  }

  Widget _buildStudentRiskCard(Map<String, dynamic> student) {
    final riskLevel = student['riskLevel'] as String;
    final riskScore = student['riskScore'] as int;
    final riskFactors = student['riskFactors'] as List<dynamic>? ?? [];

    final riskColor = riskLevel == 'critical'
        ? const Color(0xFFDC2626)
        : riskLevel == 'high'
        ? const Color(0xFFF59E0B)
        : riskLevel == 'medium'
        ? const Color(0xFF4F46E5)
        : const Color(0xFF059669);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: riskColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: riskColor.withOpacity(0.1),
                  child: Text(
                    (student['studentName'] as String? ?? '')[0],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['studentName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        student['studentCode'] ?? '',
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
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${riskLevel.toUpperCase()} ($riskScore)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Risk Factors
            const Text(
              'Risk Factors:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: riskFactors
                  .map(
                    (factor) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        factor as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Stats
            Row(
              children: [
                _buildStat(
                  'Attendance',
                  '${student['attendanceRate']?.toStringAsFixed(1) ?? 0}%',
                ),
                const SizedBox(width: 24),
                _buildStat('Due Fees', '₹${student['totalDue'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _callParent(student),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Parent'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _sendAlert(student),
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('Send Alert'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _scheduleCounseling(student),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Schedule Counseling'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: riskColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
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
          ElevatedButton(onPressed: _loadRiskData, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _sendBulkAlerts() {
    // Send alerts to all at-risk students — pending feature gate
  }

  void _callParent(Map<String, dynamic> student) {
    // Initiate phone call — pending feature gate
  }

  void _sendAlert(Map<String, dynamic> student) {
    // Send notification alert — pending feature gate
  }

  void _scheduleCounseling(Map<String, dynamic> student) {
    // Schedule counseling session — pending feature gate
  }
}
