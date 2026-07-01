import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';

class LabTestSelector extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSelected;

  const LabTestSelector({super.key, required this.onSelected});

  @override
  State<LabTestSelector> createState() => _LabTestSelectorState();
}

class _LabTestSelectorState extends State<LabTestSelector> {
  final Set<String> _selectedTests = {};
  final TextEditingController _searchController = TextEditingController();

  // Common lab tests with approx prices
  static const List<Map<String, dynamic>> _commonTests = [
    {'name': 'Complete Blood Count (CBC)', 'price': 300.0},
    {'name': 'Lipid Profile', 'price': 600.0},
    {'name': 'Liver Function Test (LFT)', 'price': 700.0},
    {'name': 'Kidney Function Test (KFT)', 'price': 800.0},
    {'name': 'Thyroid Profile (T3, T4, TSH)', 'price': 500.0},
    {'name': 'HbA1c', 'price': 400.0},
    {'name': 'Blood Sugar (Fasting)', 'price': 100.0},
    {'name': 'Blood Sugar (PP)', 'price': 100.0},
    {'name': 'Urine Routine', 'price': 150.0},
    {'name': 'Dengue NS1 Antigen', 'price': 600.0},
    {'name': 'Typhoid (Widal)', 'price': 200.0},
    {'name': 'Vitamin D', 'price': 1200.0},
    {'name': 'Vitamin B12', 'price': 900.0},
    {'name': 'X-Ray Chest PA View', 'price': 300.0},
    {'name': 'Ultrasound Abdomen', 'price': 800.0},
    {'name': 'ECG', 'price': 250.0},
  ];

  List<Map<String, dynamic>> _filteredTests = [];

  @override
  void initState() {
    super.initState();
    _filteredTests = List.from(_commonTests);
  }

  void _filterTests(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTests = List.from(_commonTests);
      } else {
        _filteredTests = _commonTests
            .where(
              (test) => test['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  void _addCustomTest() {
    if (_searchController.text.isNotEmpty) {
      final customTestName = _searchController.text;
      if (!_selectedTests.contains(customTestName)) {
        setState(() {
          _selectedTests.add(customTestName);
          _searchController.clear();
          _filterTests('');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: FuturisticColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Lab Tests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Input
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search or type new test...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, color: FuturisticColors.primary),
                onPressed: _addCustomTest,
                tooltip: 'Add Custom Test',
              ),
              filled: true,
              fillColor: FuturisticColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _filterTests,
            onSubmitted: (_) => _addCustomTest(),
          ),
          const SizedBox(height: 16),

          // Selected Chips
          if (_selectedTests.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTests.map((testName) {
                return Chip(
                  label: Text(testName),
                  backgroundColor: FuturisticColors.primary.withOpacity(0.2),
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteIconColor: Colors.white70,
                  onDeleted: () {
                    setState(() => _selectedTests.remove(testName));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Test List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTests.length,
              itemBuilder: (context, index) {
                final test = _filteredTests[index];
                final isSelected = _selectedTests.contains(test['name']);

                return ListTile(
                  title: Text(
                    test['name'],
                    style: TextStyle(
                      color: isSelected
                          ? FuturisticColors.primary
                          : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '₹${test['price']}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected
                        ? FuturisticColors.primary
                        : Colors.white54,
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTests.remove(test['name']);
                      } else {
                        _selectedTests.add(test['name']);
                      }
                    });
                  },
                );
              },
            ),
          ),

          // Done Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedTests.isEmpty
                  ? null
                  : () {
                      final selectedList = _selectedTests.map((name) {
                        // Find price from common list or default
                        final common = _commonTests.firstWhere(
                          (t) => t['name'] == name,
                          orElse: () => {'name': name, 'price': 0.0},
                        );
                        return common;
                      }).toList();

                      widget.onSelected(selectedList);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Selection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
