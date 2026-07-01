// ============================================================================
// ACADEMIC COACHING — STUDENTS LIST SCREEN
// ============================================================================
// Modern data table with search, filters, and batch actions

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcStudentsScreen extends StatefulWidget {
  const AcStudentsScreen({super.key});

  @override
  State<AcStudentsScreen> createState() => _AcStudentsScreenState();
}

class _AcStudentsScreenState extends State<AcStudentsScreen> {
  late AcRepository _repository;
  List<AcStudent> _students = [];
  List<AcBatch> _batches = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  String? _selectedBatchId;
  StudentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _repository = sl<AcRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [students, batches] = await Future.wait([
        _repository.listStudents(
          batchId: _selectedBatchId,
          search: _searchQuery.isEmpty ? null : _searchQuery,
          status: _selectedStatus?.name,
        ),
        _repository.listBatches(),
      ]);

      setState(() {
        _students = students as List<AcStudent>;
        _batches = batches as List<AcBatch>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load students: $e';
        _isLoading = false;
      });
    }
  }

  List<AcStudent> get _filteredStudents {
    return _students.where((s) {
      if (_selectedStatus != null && s.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 12,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              _buildFilters(isMobile),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildError()
                    : _buildStudentsTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Students',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_students.length} total students enrolled',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );

    final actionRow = Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/ac/students/new'),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleColumn, const SizedBox(height: 16), actionRow],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleColumn,
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push('/ac/students/new'),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add Student'),
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

  Widget _buildFilters(bool isMobile) {
    final searchField = TextField(
      onChanged: (v) {
        _searchQuery = v;
        _loadData();
      },
      decoration: InputDecoration(
        hintText: 'Search by name, phone, or ID...',
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
    );

    final batchDropdown = DropdownButtonFormField<String?>(
      value: _selectedBatchId,
      decoration: InputDecoration(
        labelText: 'Batch',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
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
        const DropdownMenuItem(value: null, child: Text('All Batches')),
        ..._batches.map(
          (b) => DropdownMenuItem(
            value: b.id,
            child: Text(b.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _selectedBatchId = v);
        _loadData();
      },
    );

    final statusDropdown = DropdownButtonFormField<StudentStatus?>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
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
        ...StudentStatus.values.map(
          (s) => DropdownMenuItem(value: s, child: Text(_getStatusLabel(s))),
        ),
      ],
      onChanged: (v) {
        setState(() => _selectedStatus = v);
        _loadData();
      },
    );

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
      child: isMobile
          ? Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: batchDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: statusDropdown),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 2, child: searchField),
                const SizedBox(width: 16),
                Expanded(child: batchDropdown),
                const SizedBox(width: 16),
                Expanded(child: statusDropdown),
              ],
            ),
    );
  }

  Widget _buildStudentsTable() {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
    );

    return Container(
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
      child: DataTable2(
        minWidth: 800,
        columnSpacing: 16,
        horizontalMargin: 16,
        headingRowHeight: 48,
        dataRowHeight: 64,
        columns: const [
          DataColumn2(label: Text('Student'), size: ColumnSize.L),
          DataColumn2(label: Text('Contact'), size: ColumnSize.M),
          DataColumn2(label: Text('Batch'), size: ColumnSize.M),
          DataColumn2(label: Text('Fee Balance'), size: ColumnSize.S),
          DataColumn2(label: Text('Attendance'), size: ColumnSize.S),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredStudents.map((student) {
          return DataRow2(
            cells: [
              // Student
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                      backgroundImage: student.photoUrl != null
                          ? NetworkImage(student.photoUrl!)
                          : null,
                      child: student.photoUrl == null
                          ? Text(
                              student.firstName[0],
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            student.studentId,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Contact
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.phone),
                    if (student.parentPhone != null)
                      Text(
                        'Parent: ${student.parentPhone}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              // Batch
              DataCell(
                student.batchNames != null && student.batchNames!.isNotEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: student.batchNames!
                            .map(
                              (b) => Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  b,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : const Text('-'),
              ),
              // Fee Balance
              DataCell(
                Text(
                  student.balance != null && student.balance! > 0
                      ? fmt.format(student.balance!)
                      : 'Paid',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: student.balance != null && student.balance! > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                  ),
                ),
              ),
              // Attendance
              DataCell(
                student.attendancePercentage != null
                    ? Row(
                        children: [
                          Container(
                            width: 40,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: student.attendancePercentage! / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: student.attendancePercentage! >= 75
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${student.attendancePercentage}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: student.attendancePercentage! >= 75
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text('-'),
              ),
              // Status
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: student.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    student.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: student.statusColor,
                    ),
                  ),
                ),
              ),
              // Actions
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      onPressed: () => _showStudentDetail(student),
                      tooltip: 'View',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editStudent(student),
                      tooltip: 'Edit',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'collect_fee',
                          child: Row(
                            children: [
                              Icon(Icons.payments, size: 18),
                              SizedBox(width: 8),
                              Text('Collect Fee'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz, size: 18),
                              SizedBox(width: 8),
                              Text('Transfer Batch'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) => _handleAction(value, student),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
        empty: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 16),
              Text(
                'No students found',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
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

  String _getStatusLabel(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.inactive:
        return 'Inactive';
      case StudentStatus.graduated:
        return 'Graduated';
      case StudentStatus.transferred:
        return 'Transferred';
    }
  }

  void _showStudentDetail(AcStudent student) {
    // Pending: Navigate to student detail
  }

  void _editStudent(AcStudent student) {
    // Pending: Navigate to edit screen
  }

  void _handleAction(String action, AcStudent student) async {
    switch (action) {
      case 'collect_fee':
        context.push('/ac/fees/collect', extra: student);
        break;
      case 'transfer':
        _showTransferDialog(student);
        break;
      case 'delete':
        _confirmDelete(student);
        break;
    }
  }

  void _showTransferDialog(AcStudent student) {
    // Pending: Show batch transfer dialog
  }

  void _confirmDelete(AcStudent student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text(
          'This will deactivate ${student.fullName}. This action can be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _repository.deleteStudent(student.id);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${student.fullName} deactivated')),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
