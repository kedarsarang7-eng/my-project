// ============================================================================
// SCHOOL ERP — CLASSWISE FEE STRUCTURE SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcClasswiseFeeScreen extends StatefulWidget {
  const AcClasswiseFeeScreen({super.key});

  @override
  State<AcClasswiseFeeScreen> createState() => _AcClasswiseFeeScreenState();
}

class _AcClasswiseFeeScreenState extends State<AcClasswiseFeeScreen> {
  late AcRepository _repository;

  List<AcClassRoom> _classes = [];
  List<AcFeeStructure> _feeStructures = [];
  AcClassRoom? _selectedClass;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);
  final _fmt = NumberFormat('#,##,###', 'en_IN');

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
      final classes = await _repository.listClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
        if (classes.isNotEmpty && _selectedClass == null) {
          _selectedClass = classes.first;
          _loadFeeStructure(classes.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load classes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFeeStructure(String classId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final structures = await _repository.listFeeStructures(classId: classId);
      setState(() {
        _feeStructures = structures;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _feeStructures = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddFeeDialog({AcFeeStructure? existing}) async {
    final headCtrl = TextEditingController(text: existing?.feeHead ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amountRupees.toStringAsFixed(0) : '',
    );
    final dueDayCtrl = TextEditingController(
      text: existing?.dueDayOfMonth?.toString() ?? '',
    );
    String frequency = existing?.frequency ?? 'monthly';
    bool isOptional = existing?.isOptional ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            existing == null ? 'Add Fee Head' : 'Edit Fee Head',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(headCtrl, 'Fee Head', 'e.g. Tuition Fee, Lab Fee'),
                const SizedBox(height: 12),
                _dialogField(
                  amountCtrl,
                  'Amount (₹)',
                  '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: _inputDecoration('Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'quarterly',
                      child: Text('Quarterly'),
                    ),
                    DropdownMenuItem(
                      value: 'half_yearly',
                      child: Text('Half Yearly'),
                    ),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                    DropdownMenuItem(
                      value: 'one_time',
                      child: Text('One-Time'),
                    ),
                  ],
                  onChanged: (v) => setD(() => frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  dueDayCtrl,
                  'Due Day of Month',
                  'e.g. 10',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isOptional,
                  onChanged: (v) => setD(() => isOptional = v),
                  title: const Text(
                    'Optional Fee',
                    style: TextStyle(fontSize: 14),
                  ),
                  activeColor: _teal,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () async {
                if (headCtrl.text.trim().isEmpty ||
                    amountCtrl.text.trim().isEmpty)
                  return;
                Navigator.pop(ctx);
                await _saveFeeHead(
                  existing: existing,
                  feeHead: headCtrl.text.trim(),
                  amount: double.tryParse(amountCtrl.text) ?? 0,
                  frequency: frequency,
                  dueDay: int.tryParse(dueDayCtrl.text),
                  isOptional: isOptional,
                );
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFeeHead({
    AcFeeStructure? existing,
    required String feeHead,
    required double amount,
    required String frequency,
    int? dueDay,
    required bool isOptional,
  }) async {
    if (_selectedClass == null) return;
    setState(() => _isSaving = true);
    try {
      if (existing == null) {
        await _repository.createFeeStructure(
          classId: _selectedClass!.id,
          feeHead: feeHead,
          amountRupees: amount,
          frequency: frequency,
          dueDayOfMonth: dueDay,
          isOptional: isOptional,
        );
      } else {
        await _repository.updateFeeStructure(
          structureId: existing.id,
          classId: _selectedClass!.id,
          feeHead: feeHead,
          amountRupees: amount,
          frequency: frequency,
          dueDayOfMonth: dueDay,
          isOptional: isOptional,
        );
      }
      await _loadFeeStructure(_selectedClass!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteFeeHead(AcFeeStructure s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Head'),
        content: Text('Delete "${s.feeHead}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || _selectedClass == null) return;
    try {
      await _repository.deleteFeeStructure(_selectedClass!.id, s.id);
      await _loadFeeStructure(_selectedClass!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClassList(),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildFeeTable()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_outlined, color: _teal, size: 24),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Classwise Fee Structure',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                'Define fee heads and amounts per class',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_selectedClass != null) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => _showAddFeeDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Fee Head'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassList() {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Classes',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _classes.length,
              itemBuilder: (_, i) {
                final cls = _classes[i];
                final isSelected = _selectedClass?.id == cls.id;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: _teal.withOpacity(0.08),
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? _teal : Colors.grey.shade200,
                    radius: 16,
                    child: Text(
                      cls.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    cls.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    '${cls.sections.length ?? 0} sections',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    setState(() => _selectedClass = cls);
                    _loadFeeStructure(cls.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTable() {
    if (_selectedClass == null) {
      return const Center(child: Text('Select a class to view fee structure'));
    }

    final annual = _feeStructures.fold<double>(0, (s, f) {
      switch (f.frequency) {
        case 'monthly':
          return s + f.amountRupees * 12;
        case 'quarterly':
          return s + f.amountRupees * 4;
        case 'half_yearly':
          return s + f.amountRupees * 2;
        default:
          return s + f.amountRupees;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _teal.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              _summaryTile('Class', _selectedClass!.name, Icons.class_outlined),
              const SizedBox(width: 24),
              _summaryTile(
                'Fee Heads',
                _feeStructures.length.toString(),
                Icons.list_outlined,
              ),
              const SizedBox(width: 24),
              _summaryTile(
                'Annual Total',
                '₹${_fmt.format(annual.toInt())}',
                Icons.currency_rupee_outlined,
              ),
              const SizedBox(width: 24),
              _summaryTile(
                'Optional',
                _feeStructures.where((f) => f.isOptional).length.toString(),
                Icons.info_outline,
              ),
            ],
          ),
        ),
        if (_feeStructures.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No fee heads defined for ${_selectedClass!.name}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    onPressed: () => _showAddFeeDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Fee Head'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Fee Head',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Amount (₹)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Frequency',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Due Day',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Type',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(width: 80),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _feeStructures.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _buildFeeRow(_feeStructures[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeeRow(AcFeeStructure s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.isOptional ? Colors.orange : _teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  s.feeHead,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${_fmt.format(s.amountRupees.toInt())}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _teal),
            ),
          ),
          Expanded(flex: 2, child: _freqChip(s.frequency)),
          Expanded(
            flex: 2,
            child: Text(
              s.dueDayOfMonth != null ? '${s.dueDayOfMonth}th' : '—',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          SizedBox(
            width: 80,
            child: s.isOptional
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Mandatory',
                      style: TextStyle(
                        fontSize: 11,
                        color: _teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showAddFeeDialog(existing: s),
                  tooltip: 'Edit',
                  color: Colors.grey,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deleteFeeHead(s),
                  tooltip: 'Delete',
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _teal, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _freqChip(String freq) {
    final labels = {
      'monthly': 'Monthly',
      'quarterly': 'Quarterly',
      'half_yearly': 'Half-Yearly',
      'annual': 'Annual',
      'one_time': 'One-Time',
    };
    return Text(labels[freq] ?? freq, style: const TextStyle(fontSize: 13));
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(label).copyWith(hintText: hint),
    );
  }
}
