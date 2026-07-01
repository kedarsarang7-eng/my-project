// ============================================================================
// PATIENT VISIT STATEMENT SCREEN - Phase 2.5
// ============================================================================
// Patient visits for Clinic/Pharmacy
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/statements_service.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientVisitStatementScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final String? patientName;

  const PatientVisitStatementScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  ConsumerState<PatientVisitStatementScreen> createState() =>
      _PatientVisitStatementScreenState();
}

class _PatientVisitStatementScreenState
    extends ConsumerState<PatientVisitStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();

  bool _isLoading = true;
  PatientVisitStatement? _statement;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generatePatientVisitStatement(
        patientId: widget.patientId,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _statement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _loadStatement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Visit Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.patientName != null)
              Text(
                widget.patientName!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _statement != null && _statement!.entries.isNotEmpty ? () {} : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          _buildDateFilterBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _statement == null || _statement!.entries.isEmpty
                        ? _buildEmptyState()
                        : _buildStatementContent(isDark),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDateFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildDateButton(label: 'From', date: _startDate, onTap: () => _pickDate(true), isDark: isDark)),
          const SizedBox(width: 16),
          Icon(Icons.arrow_forward, color: isDark ? Colors.white60 : Colors.grey),
          const SizedBox(width: 16),
          Expanded(child: _buildDateButton(label: 'To', date: _endDate, onTap: () => _pickDate(false), isDark: isDark)),
        ],
      ),
    );
  }

  Widget _buildDateButton({required String label, required DateTime? date, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading statement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStatement, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital_outlined, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('No visit records found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date range',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).disabledColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(isDark),
          const SizedBox(height: 24),
          if (_statement!.doctorVisitCounts.isNotEmpty) ...[
            _buildDoctorSummary(isDark),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visit Records',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} visits',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._statement!.entries.map((entry) => _buildVisitEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard('Total Visits', '${_statement!.totalVisits}', 'Patients seen', Colors.blue, isDark),
        _buildSummaryCard('Consultation', _formatCurrency(_statement!.totalConsultationFees), 'Fees earned', Colors.green, isDark),
        _buildSummaryCard('Medicines', _formatCurrency(_statement!.totalMedicineAmount), 'Sales', Colors.orange, isDark),
        _buildSummaryCard('Total Revenue', _formatCurrency(_statement!.totalRevenue), 'All sources', Colors.purple, isDark),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, String subtitle, Color color, bool isDark) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildDoctorSummary(bool isDark) {
    final sortedDoctors = _statement!.doctorVisitCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visits by Doctor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sortedDoctors.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: FuturisticColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${e.value} visits',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FuturisticColors.primary),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVisitEntry(PatientVisitEntry entry, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: FuturisticColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.person, color: FuturisticColors.primary, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (entry.patientAge != null || entry.patientGender != null)
                    Text(
                      '${entry.patientAge != null ? '${entry.patientAge} yrs' : ''} ${entry.patientGender ?? ''}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatCurrency(entry.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _formatDate(entry.visitDate),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Dr. ${entry.doctorName} • ${entry.visitType}',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (entry.chiefComplaint != null)
                  _buildDetailRow('Complaint', entry.chiefComplaint!, isDark),
                if (entry.diagnosis != null)
                  _buildDetailRow('Diagnosis', entry.diagnosis!, isDark),
                _buildDetailRow('Consultation Fee', _formatCurrency(entry.consultationFee), isDark),
                _buildDetailRow('Medicine Amount', _formatCurrency(entry.medicineAmount), isDark),
                if (entry.followUpDate != null)
                  _buildDetailRow('Follow-up', _formatDate(entry.followUpDate!), isDark, valueColor: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600))),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
