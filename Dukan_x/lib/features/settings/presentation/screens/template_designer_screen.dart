import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bill_template.dart';

// Simple StateProvider for the current template being edited
import '../providers/settings_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// State for the current edits
final editingTemplateProvider = NotifierProvider<EditingTemplate, BillTemplate>(
  EditingTemplate.new,
);

class EditingTemplate extends Notifier<BillTemplate> {
  @override
  BillTemplate build() => const BillTemplate();

  void setTemplate(BillTemplate template) {
    state = template;
  }
}

class BillTemplateDesignerScreen extends ConsumerWidget {
  const BillTemplateDesignerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplate = ref.watch(currentTemplateProvider);

    return asyncTemplate.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (data) {
        final current = ref.watch(editingTemplateProvider);
        // Use data (server template) if we haven't started editing yet (current is default)
        final template = current == const BillTemplate() ? data : current;

        return Scaffold(
          appBar: AppBar(title: const Text('Bill Layout Designer')),
          body: BoundedBox(
            maxWidth: 800,
            child: Column(
            children: [
              // Preview Area
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 5,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: _getAlign(template.headerAlignment),
                        children: [
                          if (template.showLogo)
                            const Icon(
                              Icons.store,
                              size: 50,
                              color: Colors.indigo,
                            ),
                          if (template.showShopName)
                            Text(
                              'DUKAN EXTRA',
                              style: TextStyle(
                                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (template.showAddress)
                            const Text(
                              '123, Market Yard, Pune - 411037',
                              style: TextStyle(color: Colors.grey),
                            ),
                          if (template.showPhone)
                            const Text(
                              'Phone: 9876543210',
                              style: TextStyle(color: Colors.grey),
                            ),

                          const Divider(thickness: 2),

                          // Bill Table Mock
                          Table(
                            border: TableBorder.all(color: Colors.black12),
                            children: const [
                              TableRow(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Qty',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Amount',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('Sugar'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('2 kg'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('80.00'),
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('Oil'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('1 L'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('120.00'),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (template.showTax)
                                    const Text('Tax (5%): 10.00'),
                                  Text(
                                    'Total: 210.00',
                                    style: TextStyle(
                                      fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(thickness: 2),
                          Center(
                            child: Text(
                              template.footerText,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Controls Area
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey[100],
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Header Settings',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        title: const Text('Show Logo'),
                        value: template.showLogo,
                        onChanged: (v) => ref
                            .read(editingTemplateProvider.notifier)
                            .setTemplate(template.copyWith(showLogo: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Show Shop Name'),
                        value: template.showShopName,
                        onChanged: (v) => ref
                            .read(editingTemplateProvider.notifier)
                            .setTemplate(template.copyWith(showShopName: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Show Address/Phone'),
                        value: template.showAddress,
                        onChanged: (v) => ref
                            .read(editingTemplateProvider.notifier)
                            .setTemplate(
                              template.copyWith(showAddress: v, showPhone: v),
                            ),
                      ),
                      const Divider(),
                      const Text(
                        'Columns',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        title: const Text('Show Tax Breakdown'),
                        value: template.showTax,
                        onChanged: (v) => ref
                            .read(editingTemplateProvider.notifier)
                            .setTemplate(template.copyWith(showTax: v)),
                      ),
                      const Divider(),
                      const Text(
                        'Alignment',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'left', label: Text('Left')),
                          ButtonSegment(value: 'center', label: Text('Center')),
                          ButtonSegment(value: 'right', label: Text('Right')),
                        ],
                        selected: {template.headerAlignment},
                        onSelectionChanged: (Set<String> newSelection) {
                          ref
                              .read(editingTemplateProvider.notifier)
                              .setTemplate(
                                template.copyWith(
                                  headerAlignment: newSelection.first,
                                ),
                              );
                        },
                      ),
                      const Divider(),
                      const Text(
                        'Footer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Footer Text',
                        ),
                        onChanged: (v) => ref
                            .read(editingTemplateProvider.notifier)
                            .setTemplate(template.copyWith(footerText: v)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await ref
                              .read(billTemplateRepositoryProvider)
                              .saveTemplate(template);
                          // Refresh the provider
                          ref.invalidate(currentTemplateProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Template Saved!')),
                            );
                          }
                        },
                        child: const Text('Save Template'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  CrossAxisAlignment _getAlign(String align) {
    switch (align) {
      case 'left':
        return CrossAxisAlignment.start;
      case 'right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.center;
    }
  }
}
