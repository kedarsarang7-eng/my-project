import 'package:excel/excel.dart';
import '../../models/export_data.dart';
import 'export_adapter.dart';

class ExcelExportAdapter implements ExportAdapter {
  @override
  String get fileExtension => 'xlsx';

  @override
  String get contentType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<List<int>> generate(ExportData data) async {
    final excel = Excel.createExcel();
    // Rename default sheet or use it
    final sheetName = 'Invoice ${data.document.number}';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }

    final Sheet sheet = excel[sheetName];

    // Style for Headers
    // final headerStyle = CellStyle(
    //   bold: true,
    //   horizontalAlign: HorizontalAlign.Center,
    //   backgroundColorHex: ExcelColor.blue200,
    // );

    // --- COMPANY INFO ---
    sheet.appendRow([TextCellValue(data.company.name.toUpperCase())]);
    sheet.appendRow([TextCellValue(data.company.address)]);
    if (data.company.gstin != null) {
      sheet.appendRow([TextCellValue('GSTIN: ${data.company.gstin}')]);
    }
    sheet.appendRow([TextCellValue('')]); // Spacer

    // --- INVOICE INFO ---
    sheet.appendRow([
      TextCellValue('Invoice No'),
      TextCellValue(data.document.number),
      TextCellValue('Date'),
      TextCellValue(data.document.date.toString().split(' ')[0]),
    ]);
    sheet.appendRow([
      TextCellValue('Customer'),
      TextCellValue(data.party.name),
      TextCellValue('Phone'),
      TextCellValue(data.party.phone ?? ''),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // --- TABLE HEADERS ---
    final headers = [
      TextCellValue('Sl No'),
      TextCellValue('Item Name'),
      TextCellValue('Qty'),
      TextCellValue('Unit'),
      TextCellValue('Price'),
      TextCellValue('Tax Amt'),
      TextCellValue('Total'),
    ];
    sheet.appendRow(headers);
    // Apply bold to header row (last added row) - tricky in excel lib, usually done by iterating cells
    // Leaving styling simple for now.

    // --- ITEMS ---
    for (final item in data.items) {
      sheet.appendRow([
        IntCellValue(item.index),
        TextCellValue(item.name),
        DoubleCellValue(item.quantity),
        TextCellValue(item.unit),
        DoubleCellValue(item.unitPrice),
        DoubleCellValue(item.taxAmount),
        DoubleCellValue(item.totalAmount),
      ]);
    }

    // --- TOTALS ---
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Subtotal'),
      DoubleCellValue(data.totals.subtotal),
    ]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Tax'),
      DoubleCellValue(data.totals.totalTax),
    ]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Grand Total'),
      DoubleCellValue(data.totals.grandTotal),
    ]);

    return excel.save() ?? [];
  }
}
