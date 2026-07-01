import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Sibling Linking Screen - Family Management
class AcSiblingScreen extends ConsumerStatefulWidget {
  const AcSiblingScreen({super.key});

  @override
  ConsumerState<AcSiblingScreen> createState() => _AcSiblingScreenState();
}

class _AcSiblingScreenState extends ConsumerState<AcSiblingScreen> {
  String _selectedView = 'families';
  List<Map<String, dynamic>> _families = [];

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Sibling Linking',
      actions: [
        FilledButton.icon(
          onPressed: () => _showLinkSiblingsDialog(),
          icon: const Icon(Icons.link),
          label: const Text('Link Siblings'),
        ),
      ],
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'families', label: Text('Families')),
              ButtonSegment(value: 'students', label: Text('Students')),
            ],
            selected: {_selectedView},
            onSelectionChanged: (set) =>
                setState(() => _selectedView = set.first),
          ),
          const SizedBox(height: 16),
          _buildDiscountInfoCard(),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedView == 'families'
                ? _buildFamiliesView()
                : _buildStudentsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInfoCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_offer, color: Colors.green.shade700, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sibling Discount Policy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• 5% discount for 2nd sibling\n• 10% discount for 3rd sibling\n• 15% discount for 4th+ sibling\n• 25% discount for staff children',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamiliesView() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        final siblingCount = (index % 4) + 2; // 2-5 siblings
        final discount = siblingCount == 2
            ? 5
            : siblingCount == 3
            ? 10
            : siblingCount == 4
            ? 15
            : 15;

        return Card(
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text('F${index + 1}'),
            ),
            title: Text('Family Group ${index + 1}'),
            subtitle: Text('$siblingCount siblings enrolled'),
            trailing: Chip(
              label: Text('$discount% OFF'),
              backgroundColor: Colors.green.shade100,
            ),
            children: List.generate(siblingCount, (sIndex) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text('${sIndex + 1}'),
                ),
                title: Text('Student ${sIndex + 1} (Family ${index + 1})'),
                subtitle: Text('Class ${5 + sIndex}'),
                trailing: TextButton(
                  onPressed: () => _unlinkSibling(index, sIndex),
                  child: const Text('Unlink'),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStudentsView() {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        final hasSibling = index % 3 == 0;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: hasSibling
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Icon(
                hasSibling ? Icons.people : Icons.person,
                color: hasSibling ? Colors.green : Colors.grey,
              ),
            ),
            title: Text('Student ${index + 1}'),
            subtitle: Text(
              hasSibling ? 'Has sibling(s)' : 'No siblings linked',
            ),
            trailing: hasSibling
                ? const Chip(
                    label: Text('Linked'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        _showLinkSiblingsDialog(studentIndex: index),
                    child: const Text('Link'),
                  ),
          ),
        );
      },
    );
  }

  void _showLinkSiblingsDialog({int? studentIndex}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Siblings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (studentIndex != null)
                Chip(label: Text('Primary: Student ${studentIndex + 1}')),
              const SizedBox(height: 16),
              const Text('Select siblings to link:'),
              const SizedBox(height: 8),
              // Search field
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search students...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Multi-select list
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return CheckboxListTile(
                      value: false,
                      onChanged: (v) {},
                      title: Text('Student ${index + 100}'),
                      subtitle: Text('Class ${index % 10 + 1}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmLink();
            },
            icon: const Icon(Icons.link),
            label: const Text('Link Selected'),
          ),
        ],
      ),
    );
  }

  void _confirmLink() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sibling Link'),
        content: const Text(
          'Selected siblings will be linked to the same family group. '
          'Discount will be automatically calculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Siblings linked successfully')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _unlinkSibling(int familyIndex, int studentIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Sibling?'),
        content: Text(
          'Remove Student ${studentIndex + 1} from Family Group ${familyIndex + 1}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sibling unlinked')));
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}
