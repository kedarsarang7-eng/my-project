// ============================================================================
// ACADEMIC COACHING — BULK OPERATIONS SCREEN
// ============================================================================
// CSV import, bulk invoicing, and mass operations with modern UI

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcBulkOperationsScreen extends StatefulWidget {
  const AcBulkOperationsScreen({super.key});

  @override
  State<AcBulkOperationsScreen> createState() => _AcBulkOperationsScreenState();
}

class _AcBulkOperationsScreenState extends State<AcBulkOperationsScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  List<AcBatch> _batches = [];
  List<AcCourse> _courses = [];
  bool _isLoading = true;
  String? _error;

  // CSV Import state
  List<Map<String, dynamic>> _previewData = [];
  bool _isImporting = false;
  String? _selectedBatchId;
  String? _selectedCourseId;

  // Bulk Invoice state
  bool _isGenerating = false;
  final List<Map<String, dynamic>> _feeComponents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = sl<AcRepository>();
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
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importStudents() async {
    if (_previewData.isEmpty ||
        (_selectedBatchId == null && _selectedCourseId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select batch/course and preview data first'),
        ),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final result = await _repository.bulkImportStudents(
        students: _previewData,
        batchId: _selectedBatchId,
        courseId: _selectedCourseId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Imported ${result['imported']} students (${result['failed']} failed)',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        setState(() {
          _previewData = [];
          _isImporting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _generateBulkInvoices() async {
    if (_feeComponents.isEmpty ||
        (_selectedBatchId == null && _selectedCourseId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select batch/course and add fee components'),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await _repository.bulkGenerateInvoices(
        batchId: _selectedBatchId,
        courseId: _selectedCourseId,
        feeComponents: _feeComponents,
        dueDate: DateTime.now()
            .add(const Duration(days: 10))
            .toIso8601String()
            .split('T')[0],
        description: 'Monthly tuition fee',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated ${result['generated']} invoices'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        setState(() => _isGenerating = false);
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

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isMobile),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
              tabs: const [
                Tab(icon: Icon(Icons.upload_file), text: 'CSV Import'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Bulk Invoices'),
                Tab(icon: Icon(Icons.card_giftcard), text: 'Certificates'),
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
                        _buildCsvImportTab(isMobile),
                        _buildBulkInvoicesTab(isMobile),
                        _buildBulkCertificatesTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Operations',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perform mass operations efficiently',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ],
            ),
          ),
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCsvImportTab(bool isMobile) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUploadSection(),
        const SizedBox(height: 20),
        _buildSelectionSection(),
      ],
    );

    return isMobile
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn,
                const SizedBox(height: 16),
                _buildPreviewSection(true),
              ],
            ),
          )
        : Padding(
            padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: leftColumn,
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: _buildPreviewSection(false),
                ),
              ],
            ),
          );
  }

  Widget _buildUploadSection() {
    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload CSV File',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(responsiveValue<double>(context,
              mobile: 16,
              tablet: 20,
              desktop: 32,  // PRESERVED: Desktop uses exactly 32 as before
            )),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Drag & drop CSV file here',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _simulateCsvUpload(),
                  child: const Text('Browse Files'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Sample CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSection() {
    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBatchId,
            decoration: const InputDecoration(
              labelText: 'Target Batch (Optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select Batch')),
              ..._batches.map(
                (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
              ),
            ],
            onChanged: (v) => setState(() => _selectedBatchId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCourseId,
            decoration: const InputDecoration(
              labelText: 'Target Course (Optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select Course')),
              ..._courses.map(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
              ),
            ],
            onChanged: (v) => setState(() => _selectedCourseId = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(bool isMobile) {
    final previewContent = _previewData.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_chart,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload CSV to preview data',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        : ListView.builder(
            shrinkWrap: isMobile,
            physics: isMobile ? const NeverScrollableScrollPhysics() : null,
            itemCount: _previewData.length,
            itemBuilder: (context, index) {
              final row = _previewData[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${index + 1}'),
                ),
                title: Text('${row['firstName']} ${row['lastName']}'),
                subtitle: Text(row['phone'] ?? ''),
              );
            },
          );

    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_previewData.isNotEmpty)
                Text(
                  '${_previewData.length} records',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          isMobile
              ? previewContent
              : Expanded(child: previewContent),
          if (_previewData.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importStudents,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isImporting ? 'Importing...' : 'Import Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkInvoicesTab(bool isMobile) {
    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate Bulk Invoices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedBatchId,
          decoration: const InputDecoration(
            labelText: 'Select Batch *',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select Batch'),
            ),
            ..._batches.map(
              (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
            ),
          ],
          onChanged: (v) => setState(() => _selectedBatchId = v),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fee Components',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._feeComponents.asMap().entries.map(
          (e) => _buildFeeComponentRow(e.key, e.value),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _feeComponents.add({'name': '', 'amount': 0});
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Component'),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateBulkInvoices,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(
              _isGenerating ? 'Generating...' : 'Generate Invoices',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      child: Container(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: formContent,
      ),
    );
  }

  Widget _buildFeeComponentRow(int index, Map<String, dynamic> component) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Component name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => component['name'] = v,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Amount',
                prefixText: sl<CurrencyService>().symbol,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => component['amount'] = double.tryParse(v) ?? 0,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _feeComponents.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBulkCertificatesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_membership, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Bulk Certificate Generation',
            style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate certificates for entire batches or courses',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Bulk operations available in next release'),
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

  void _simulateCsvUpload() {
    // Simulate CSV data for demo
    setState(() {
      _previewData = [
        {
          'firstName': 'Rahul',
          'lastName': 'Sharma',
          'phone': '9876543210',
          'parentPhone': '9876543211',
        },
        {
          'firstName': 'Priya',
          'lastName': 'Patel',
          'phone': '9876543220',
          'parentPhone': '9876543221',
        },
        {
          'firstName': 'Amit',
          'lastName': 'Kumar',
          'phone': '9876543230',
          'parentPhone': '9876543231',
        },
        {
          'firstName': 'Sneha',
          'lastName': 'Gupta',
          'phone': '9876543240',
          'parentPhone': '9876543241',
        },
        {
          'firstName': 'Vikram',
          'lastName': 'Singh',
          'phone': '9876543250',
          'parentPhone': '9876543251',
        },
      ];
    });
  }
}
