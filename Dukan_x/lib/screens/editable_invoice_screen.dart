import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../models/invoice_editable.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive Editable Invoice Screen
/// - Owner details at top (with colors)
/// - Customer details
/// - Editable items table
/// - Editable charges section
/// - Auto-calculation
/// - Signature & stamp upload
/// - PDF export

class EditableInvoiceScreen extends StatefulWidget {
  final EditableInvoice? initialInvoice;
  final String ownerName;
  final String shopName;
  final String ownerPhone;
  final String ownerAddress;

  const EditableInvoiceScreen({
    super.key,
    this.initialInvoice,
    required this.ownerName,
    required this.shopName,
    required this.ownerPhone,
    required this.ownerAddress,
  });

  @override
  State<EditableInvoiceScreen> createState() => _EditableInvoiceScreenState();
}

class _EditableInvoiceScreenState extends State<EditableInvoiceScreen> {
  late EditableInvoice _invoice;
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerVillageCtrl;
  late TextEditingController _notesCtrl;

  final List<TextEditingController> _itemNameCtrls = [];
  final List<TextEditingController> _itemManQtyCtrls = [];
  final List<TextEditingController> _itemKiloCtrls = [];
  final List<TextEditingController> _itemRatePerKiloCtrls = [];
  final List<TextEditingController> _itemManRateCtrls = [];

  late TextEditingController _okshanCtrl;
  late TextEditingController _nagarpalikaCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _hamaliCtrl;
  late TextEditingController _vetChithiCtrl;
  late TextEditingController _gadiKhadaCtrl;

  @override
  void initState() {
    super.initState();
    _initializeInvoice();
    _initializeControllers();
  }

  void _initializeInvoice() {
    _invoice =
        widget.initialInvoice ??
        EditableInvoice.empty(
          ownerName: widget.ownerName,
          shopName: widget.shopName,
          ownerPhone: widget.ownerPhone,
          ownerAddress: widget.ownerAddress,
        );
  }

  void _initializeControllers() {
    _customerNameCtrl = TextEditingController(text: _invoice.customerName);
    _customerVillageCtrl = TextEditingController(
      text: _invoice.customerVillage,
    );
    _notesCtrl = TextEditingController(text: _invoice.notes);

    // Items
    for (final item in _invoice.items) {
      _itemNameCtrls.add(TextEditingController(text: item.itemName));
      _itemManQtyCtrls.add(
        TextEditingController(text: item.manQuantity?.toString() ?? ''),
      );
      _itemKiloCtrls.add(
        TextEditingController(text: item.kiloWeight.toStringAsFixed(2)),
      );
      _itemRatePerKiloCtrls.add(
        TextEditingController(text: item.ratePerKilo.toStringAsFixed(2)),
      );
      _itemManRateCtrls.add(
        TextEditingController(text: item.manRate?.toString() ?? ''),
      );
    }

    // Charges
    _okshanCtrl = TextEditingController(
      text: _invoice.charges.okshanKharcha.toStringAsFixed(2),
    );
    _nagarpalikaCtrl = TextEditingController(
      text: _invoice.charges.nagarpalika.toStringAsFixed(2),
    );
    _commissionCtrl = TextEditingController(
      text: _invoice.charges.commission.toStringAsFixed(2),
    );
    _hamaliCtrl = TextEditingController(
      text: _invoice.charges.hamali.toStringAsFixed(2),
    );
    _vetChithiCtrl = TextEditingController(
      text: _invoice.charges.vetChithi.toStringAsFixed(2),
    );
    _gadiKhadaCtrl = TextEditingController(
      text: _invoice.charges.gadiKhada.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerVillageCtrl.dispose();
    _notesCtrl.dispose();
    for (var ctrl in _itemNameCtrls) {
      ctrl.dispose();
    }
    for (var ctrl in _itemManQtyCtrls) {
      ctrl.dispose();
    }
    for (var ctrl in _itemKiloCtrls) {
      ctrl.dispose();
    }
    for (var ctrl in _itemRatePerKiloCtrls) {
      ctrl.dispose();
    }
    for (var ctrl in _itemManRateCtrls) {
      ctrl.dispose();
    }
    _okshanCtrl.dispose();
    _nagarpalikaCtrl.dispose();
    _commissionCtrl.dispose();
    _hamaliCtrl.dispose();
    _vetChithiCtrl.dispose();
    _gadiKhadaCtrl.dispose();
    super.dispose();
  }

  void _updateInvoiceFromControllers() {
    _invoice.customerName = _customerNameCtrl.text;
    _invoice.customerVillage = _customerVillageCtrl.text;
    _invoice.notes = _notesCtrl.text;

    _invoice.charges.okshanKharcha = double.tryParse(_okshanCtrl.text) ?? 0;
    _invoice.charges.nagarpalika = double.tryParse(_nagarpalikaCtrl.text) ?? 0;
    _invoice.charges.commission = double.tryParse(_commissionCtrl.text) ?? 0;
    _invoice.charges.hamali = double.tryParse(_hamaliCtrl.text) ?? 0;
    _invoice.charges.vetChithi = double.tryParse(_vetChithiCtrl.text) ?? 0;
    _invoice.charges.gadiKhada = double.tryParse(_gadiKhadaCtrl.text) ?? 0;

    _invoice.items.clear();
    for (int i = 0; i < _itemNameCtrls.length; i++) {
      final kiloWeight = double.tryParse(_itemKiloCtrls[i].text) ?? 0;
      final ratePerKilo = double.tryParse(_itemRatePerKiloCtrls[i].text) ?? 0;
      final manQty = double.tryParse(_itemManQtyCtrls[i].text);
      final manRate = double.tryParse(_itemManRateCtrls[i].text);

      double total = kiloWeight * ratePerKilo;
      if (manQty != null && manRate != null) {
        total += manQty * manRate;
      }

      _invoice.items.add(
        EditableInvoiceItem(
          id: const Uuid().v4(),
          itemName: _itemNameCtrls[i].text,
          manQuantity: manQty,
          kiloWeight: kiloWeight,
          ratePerKilo: ratePerKilo,
          manRate: manRate,
          totalAmount: total,
        ),
      );
    }
  }

  void _addItemRow() {
    setState(() {
      _itemNameCtrls.add(TextEditingController());
      _itemManQtyCtrls.add(TextEditingController());
      _itemKiloCtrls.add(TextEditingController());
      _itemRatePerKiloCtrls.add(TextEditingController());
      _itemManRateCtrls.add(TextEditingController());
    });
  }

  void _removeItemRow(int index) {
    if (_itemNameCtrls.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item required')),
      );
      return;
    }

    setState(() {
      _itemNameCtrls[index].dispose();
      _itemManQtyCtrls[index].dispose();
      _itemKiloCtrls[index].dispose();
      _itemRatePerKiloCtrls[index].dispose();
      _itemManRateCtrls[index].dispose();

      _itemNameCtrls.removeAt(index);
      _itemManQtyCtrls.removeAt(index);
      _itemKiloCtrls.removeAt(index);
      _itemRatePerKiloCtrls.removeAt(index);
      _itemManRateCtrls.removeAt(index);
    });
  }

  double _calculateItemTotal(int index) {
    final kilo = double.tryParse(_itemKiloCtrls[index].text) ?? 0;
    final rate = double.tryParse(_itemRatePerKiloCtrls[index].text) ?? 0;
    final manQty = double.tryParse(_itemManQtyCtrls[index].text);
    final manRate = double.tryParse(_itemManRateCtrls[index].text);

    double total = kilo * rate;
    if (manQty != null && manRate != null) {
      total += manQty * manRate;
    }
    return total;
  }

  double _getItemsGrandTotal() {
    double total = 0;
    for (int i = 0; i < _itemNameCtrls.length; i++) {
      total += _calculateItemTotal(i);
    }
    return total;
  }

  double _getChargesTotal() {
    return (double.tryParse(_okshanCtrl.text) ?? 0) +
        (double.tryParse(_nagarpalikaCtrl.text) ?? 0) +
        (double.tryParse(_commissionCtrl.text) ?? 0) +
        (double.tryParse(_hamaliCtrl.text) ?? 0) +
        (double.tryParse(_vetChithiCtrl.text) ?? 0) +
        (double.tryParse(_gadiKhadaCtrl.text) ?? 0);
  }

  double _getFinalTotal() {
    return _getItemsGrandTotal() + _getChargesTotal();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Owner Details Header
        _buildOwnerDetailsCard(),
        const SizedBox(height: 16),
        // Customer Details
        _buildCustomerDetailsCard(),
        const SizedBox(height: 16),
        // Totals
        _buildTotalsCard(),
        const SizedBox(height: 16),
        // Notes
        _buildNotesCard(),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Items Table
        _buildItemsTableCard(),
        const SizedBox(height: 16),
        // Charges Section
        _buildChargesCard(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: () {
              _updateInvoiceFromControllers();
              Navigator.pop(context, _invoice);
            },
            tooltip: 'Save Invoice',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile) ...[
                leftColumn,
                const SizedBox(height: 16),
                rightColumn,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: leftColumn,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 7,
                      child: rightColumn,
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _updateInvoiceFromControllers();
                        Navigator.pop(context, _invoice);
                      },
                      child: const Text('Save & Exit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerDetailsCard() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[700]!, Colors.green[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _invoice.shopName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _invoice.ownerName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              'à¤®à¥‹: ${_invoice.ownerPhone}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              _invoice.ownerAddress,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'à¤–à¤°à¥‡à¤¦à¥€à¤¦à¤¾à¤° à¤¤à¤ªà¤¶à¥€à¤²',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'à¤—à¥à¤°à¤¾à¤¹à¤• à¤¨à¤¾à¤µ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerVillageCtrl,
              decoration: const InputDecoration(
                labelText: 'à¤—à¤¾à¤µ / à¤¶à¤¹à¤°',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'à¤¤à¤¾à¤°à¥€à¤–',
                      border: const OutlineInputBorder(),
                      hintText: _invoice.formattedDate,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'à¤¬à¤¿à¤² à¤•à¥à¤°à¤®à¤¾à¤‚à¤•',
                      border: const OutlineInputBorder(),
                      hintText: _invoice.invoiceNumber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTableCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'à¤®à¤¾à¤²à¤¾à¤šà¤¾ à¤¤à¤ªà¤¶à¥€à¤²',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addItemRow,
                  icon: const Icon(Icons.add),
                  label: const Text('à¤®à¤¾à¤²à¤¾à¤šà¥€ à¤ªà¤‚à¤•à¥à¤¤à¤¿'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('à¤®à¤¾à¤²à¤¾à¤šà¤¾ à¤µà¤¿à¤µà¤°à¤£')),
                  DataColumn(label: Text('à¤®à¤¨')),
                  DataColumn(label: Text('à¤•à¤¿à¤²à¥‹')),
                  DataColumn(label: Text('à¤­à¤¾à¤µ')),
                  DataColumn(label: Text('à¤°à¥à¤ªà¤¯à¥‡')),
                  DataColumn(label: Text('à¤à¤•à¥‚à¤£')),
                  DataColumn(label: Text('à¤•à¥à¤°à¤¿à¤¯à¤¾')),
                ],
                rows: List.generate(_itemNameCtrls.length, (index) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _itemNameCtrls[index],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _itemManQtyCtrls[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _itemKiloCtrls[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _itemRatePerKiloCtrls[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _itemManRateCtrls[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          'â‚¹${_calculateItemTotal(index).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItemRow(index),
                          iconSize: 18,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'à¤–à¤°à¥à¤š',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildChargeRow('à¤‘à¤•à¥à¤¶à¤¨ / à¤…à¤¡à¥à¤¡à¤¾ à¤–à¤°à¥à¤š', _okshanCtrl),
            _buildChargeRow('à¤¨à¤—à¤°à¤ªà¤¾à¤²à¤¿à¤•à¤¾', _nagarpalikaCtrl),
            _buildChargeRow('à¤•à¤®à¤¿à¤¶à¤¨', _commissionCtrl),
            _buildChargeRow('à¤¹à¤®à¤¾à¤²à¥€', _hamaliCtrl),
            _buildChargeRow('à¤µ. à¤šà¤¿à¤ à¥à¤ à¥€', _vetChithiCtrl),
            _buildChargeRow('à¤—à¤¾à¤¡à¥€ à¤­à¤¾à¤¡à¤¾', _gadiKhadaCtrl),
          ],
        ),
      ),
    );
  }

  Widget _buildChargeRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefix: Text('â‚¹'),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    final itemsTotal = _getItemsGrandTotal();
    final chargesTotal = _getChargesTotal();
    final finalTotal = _getFinalTotal();

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('à¤®à¤¾à¤²à¤¾à¤šà¥€ à¤à¤•à¥‚à¤£', itemsTotal),
            const Divider(),
            _buildTotalRow('à¤–à¤°à¥à¤š à¤à¤•à¥‚à¤£', chargesTotal),
            const Divider(thickness: 2),
            _buildTotalRow(
              'à¤…à¤‚à¤¤à¤¿à¤® à¤à¤•à¥‚à¤£',
              finalTotal,
              isBold: true,
              isLarge: true,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
    Color color = Colors.black,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 16 : 14,
            color: color,
          ),
        ),
        Text(
          'â‚¹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 16 : 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'à¤…à¤¤à¤¿à¤°à¤¿à¤•à¥à¤¤ à¤¨à¥‹à¤Ÿà¥à¤¸',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'à¤•à¥‹à¤£à¤¤à¥‡à¤¹à¥€ à¤…à¤¤à¤¿à¤°à¤¿à¤•à¥à¤¤ à¤¨à¥‹à¤Ÿà¥à¤¸ à¤Ÿà¤¾à¤‡à¤ª à¤•à¤°à¤¾...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
