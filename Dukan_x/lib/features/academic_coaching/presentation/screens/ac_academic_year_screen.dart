// ============================================================================
// SCHOOL ERP — ACADEMIC YEAR / TERM MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcAcademicYearScreen extends StatefulWidget {
  const AcAcademicYearScreen({super.key});

  @override
  State<AcAcademicYearScreen> createState() => _AcAcademicYearScreenState();
}

class _AcAcademicYearScreenState extends State<AcAcademicYearScreen> {
  late AcRepository _repository;
  List<AcAcademicYear> _years = [];
  bool _isLoading = true;
  String? _error;

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);
  final _fmt = DateFormat('dd MMM yyyy');

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
      final years = await _repository.listAcademicYears();
      setState(() {
        _years = years;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _years.isEmpty
                ? _buildEmpty()
                : _buildYearsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddYearDialog,
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Academic Year',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final activeYear = _years.where((y) => y.isActive).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(24),
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: _teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic Year',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    Text(
                      '${_years.length} years configured',
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
          if (activeYear != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_teal, _teal.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Academic Year',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          activeYear.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${_fmt.format(activeYear.startDate)} – ${_fmt.format(activeYear.endDate)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildProgressRing(activeYear),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRing(AcAcademicYear year) {
    final total = year.endDate.difference(year.startDate).inDays;
    final elapsed = DateTime.now()
        .difference(year.startDate)
        .inDays
        .clamp(0, total);
    final pct = total > 0 ? elapsed / total : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: pct,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            strokeWidth: 5,
          ),
        ),
        Text(
          '${(pct * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildYearsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _years.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildYearCard(_years[i]),
    );
  }

  Widget _buildYearCard(AcAcademicYear year) {
    final isActive = year.isActive;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: _teal, width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      Row(
                        children: [
                          Text(
                            year.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _teal,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fmt.format(year.startDate)} – ${_fmt.format(year.endDate)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onYearAction(v, year),
                  itemBuilder: (_) => [
                    if (!isActive)
                      const PopupMenuItem(
                        value: 'set_active',
                        child: Text('Set as Active'),
                      ),
                    const PopupMenuItem(
                      value: 'add_term',
                      child: Text('Add Term'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (year.terms.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Terms',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: year.terms.map((t) => _buildTermChip(t)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTermChip(AcTerm term) {
    final now = DateTime.now();
    final isCurrent = now.isAfter(term.startDate) && now.isBefore(term.endDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? _teal.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCurrent ? _teal : Colors.grey.shade300),
      ),
      child: Text(
        '${term.name}: ${_fmt.format(term.startDate)} – ${_fmt.format(term.endDate)}',
        style: TextStyle(
          fontSize: 12,
          color: isCurrent ? _teal : const Color(0xFF64748B),
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: _teal.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No academic years configured',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first academic year to get started',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddYearDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Academic Year'),
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
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _onYearAction(String action, AcAcademicYear year) {
    switch (action) {
      case 'set_active':
        _setActiveYear(year);
        break;
      case 'add_term':
        _showAddTermDialog(year);
        break;
      case 'edit':
        _showEditYearDialog(year);
        break;
      case 'delete':
        _confirmDeleteYear(year);
        break;
    }
  }

  Future<void> _setActiveYear(AcAcademicYear year) async {
    try {
      await _repository.setActiveAcademicYear(yearId: year.id);
      _loadData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${year.name} set as active'),
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

  void _showAddYearDialog() {
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'New Academic Year',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name (e.g. 2025-26)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setDialogState(() => startDate = d);
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        startDate != null
                            ? _fmt.format(startDate!)
                            : 'Start Date',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setDialogState(() => endDate = d);
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        endDate != null ? _fmt.format(endDate!) : 'End Date',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
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
                if (nameCtrl.text.trim().isEmpty ||
                    startDate == null ||
                    endDate == null)
                  return;
                Navigator.pop(ctx);
                try {
                  await _repository.createAcademicYear(
                    name: nameCtrl.text.trim(),
                    startDate: startDate!,
                    endDate: endDate!,
                  );
                  _loadData();
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTermDialog(AcAcademicYear year) {
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Add Term to ${year.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Term Name (e.g. Term 1, Q1, Semester 1)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: year.startDate,
                          firstDate: year.startDate,
                          lastDate: year.endDate,
                        );
                        if (d != null) setDialogState(() => startDate = d);
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        startDate != null ? _fmt.format(startDate!) : 'Start',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: year.startDate,
                          firstDate: year.startDate,
                          lastDate: year.endDate,
                        );
                        if (d != null) setDialogState(() => endDate = d);
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        endDate != null ? _fmt.format(endDate!) : 'End',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
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
                if (nameCtrl.text.trim().isEmpty ||
                    startDate == null ||
                    endDate == null)
                  return;
                Navigator.pop(ctx);
                try {
                  await _repository.addTerm(
                    yearId: year.id,
                    name: nameCtrl.text.trim(),
                    startDate: startDate!,
                    endDate: endDate!,
                  );
                  _loadData();
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditYearDialog(AcAcademicYear year) {
    final nameCtrl = TextEditingController(text: year.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Academic Year'),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
              Navigator.pop(ctx);
              try {
                await _repository.updateAcademicYear(
                  yearId: year.id,
                  name: nameCtrl.text.trim(),
                );
                _loadData();
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteYear(AcAcademicYear year) {
    if (year.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the active academic year.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Academic Year?',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Delete ${year.name}? This will also remove all associated terms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteAcademicYear(yearId: year.id);
                _loadData();
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
