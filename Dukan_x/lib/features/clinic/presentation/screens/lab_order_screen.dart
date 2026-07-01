import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/clinic_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class LabOrderScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const LabOrderScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<LabOrderScreen> createState() => _LabOrderScreenState();
}

class _LabOrderScreenState extends ConsumerState<LabOrderScreen> {
  final List<String> _availableTests = [
    'Complete Blood Count (CBC)',
    'Lipid Panel',
    'Comprehensive Metabolic Panel (CMP)',
    'HbA1c',
    'Thyroid Panel (TSH, T3, T4)',
    'Urinalysis',
    'X-Ray Chest PA',
  ];

  final Set<String> _selectedTests = {};
  bool _isOrdering = false;

  void _toggleTest(String testId) {
    setState(() {
      if (_selectedTests.contains(testId)) {
        _selectedTests.remove(testId);
      } else {
        _selectedTests.add(testId);
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one test')),
      );
      return;
    }

    setState(() => _isOrdering = true);
    final result = await ref.read(clinicRepositoryProvider).orderLabTest(widget.patientId, _selectedTests.toList());
    setState(() => _isOrdering = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to order: ${failure.message}')),
        );
      },
      (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab tests ordered successfully!')),
        );
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Labs: ${widget.patientName}'),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _availableTests.length,
              itemBuilder: (context, index) {
                final test = _availableTests[index];
                final isSelected = _selectedTests.contains(test);
                return CheckboxListTile(
                  title: Text(test),
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleTest(test);
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isOrdering ? null : _submitOrder,
                  child: _isOrdering
                      ? const CircularProgressIndicator()
                      : Text('Submit Order (${_selectedTests.length} tests)'),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
