import 'package:pdf/widgets.dart' as pw;
import 'invoice_models.dart';
import '../billing/business_type_config.dart';

/// Definition of a dynamic column in the invoice
class InvoiceColumn {
  final String key;
  final String labelIndex; // Key for localization map (e.g. 'qty', 'rate')
  final String fallbackLabel; // Fallback if localization missing
  final double flex; // Width ratio
  final pw.Alignment alignment;
  final bool
  isMandatory; // If true, always show (unless no data in entire column?)
  final String Function(EnhancedInvoiceItem) valueExtractor;

  const InvoiceColumn({
    required this.key,
    required this.labelIndex,
    required this.fallbackLabel,
    this.flex = 1.0,
    this.alignment = pw.Alignment.centerLeft,
    this.isMandatory = false,
    required this.valueExtractor,
  });
}

/// Resolves the list of columns based on Business Type
class InvoiceSchemaResolver {
  static List<InvoiceColumn> getColumns(BusinessType type, bool showTax) {
    final config = BusinessTypeRegistry.getConfig(type);
    final List<InvoiceColumn> columns = [];

    // 1. S.No (Always first)
    columns.add(
      InvoiceColumn(
        key: 'sno',
        labelIndex: 'slNo',
        fallbackLabel: '#',
        flex: 0.4,
        alignment: pw.Alignment.center,
        isMandatory: true,
        valueExtractor: (_) => '', // Handled by index in loop
      ),
    );

    // 2. Main Item Name (Always present)
    columns.add(
      InvoiceColumn(
        key: 'name',
        labelIndex: 'description', // Or use itemLabel from config?
        fallbackLabel: config.itemLabel,
        flex: 2.5,
        alignment: pw.Alignment.centerLeft,
        isMandatory: true,
        valueExtractor: (item) {
          String text = item.name;
          // Append description if small? No, handle in cell builder
          return text;
        },
      ),
    );

    // 3. Business Specific Columns (Inserted before Qty)

    // Pharmacy: Batch & Expiry
    if (config.hasField(ItemField.batchNo)) {
      columns.add(
        InvoiceColumn(
          key: 'batch',
          labelIndex: 'batch',
          fallbackLabel: 'Batch',
          flex: 0.8,
          alignment: pw.Alignment.center,
          valueExtractor: (item) => item.batchNo ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.expiryDate)) {
      columns.add(
        InvoiceColumn(
          key: 'expiry',
          labelIndex: 'expiry',
          fallbackLabel: 'Exp.',
          flex: 0.8,
          alignment: pw.Alignment.center,
          valueExtractor: (item) {
            if (item.expiryDate == null) return '-';
            return '${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year.toString().substring(2)}';
          },
        ),
      );
    }

    // Electronics: Serial / IMEI / Warranty
    if (config.hasField(ItemField.serialNo)) {
      columns.add(
        InvoiceColumn(
          key: 'serial',
          labelIndex: 'serial',
          fallbackLabel: 'SR/IMEI',
          flex: 1.0,
          alignment: pw.Alignment.centerLeft,
          valueExtractor: (item) => item.serialNo ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.warrantyMonths)) {
      columns.add(
        InvoiceColumn(
          key: 'warranty',
          labelIndex: 'warranty',
          fallbackLabel: 'War.',
          flex: 0.6,
          alignment: pw.Alignment.center,
          valueExtractor: (item) =>
              item.warrantyMonths != null ? '${item.warrantyMonths}m' : '-',
        ),
      );
    }

    // Clothing: Size & Color
    if (config.hasField(ItemField.size)) {
      columns.add(
        InvoiceColumn(
          key: 'size',
          labelIndex: 'size',
          fallbackLabel: 'Size',
          flex: 0.5,
          alignment: pw.Alignment.center,
          valueExtractor: (item) => item.size ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.color)) {
      columns.add(
        InvoiceColumn(
          key: 'color',
          labelIndex: 'color',
          fallbackLabel: 'Color',
          flex: 0.6,
          alignment: pw.Alignment.center,
          valueExtractor: (item) => item.color ?? '-',
        ),
      );
    }

    // Petrol: Fuel specific
    if (config.hasField(ItemField.fuelType)) {
      columns.add(
        InvoiceColumn(
          key: 'fuel',
          labelIndex: 'fuel',
          fallbackLabel: 'Fuel',
          flex: 0.8,
          alignment: pw.Alignment.centerLeft,
          valueExtractor: (item) => item
              .name, // Name usually contains fuel type, but if separate logic needed, use name
        ),
      );
    }

    if (config.hasField(ItemField.vehicleNumber)) {
      columns.add(
        InvoiceColumn(
          key: 'vehicle',
          labelIndex: 'vehicle',
          fallbackLabel: 'Veh. No',
          flex: 1.2,
          alignment: pw.Alignment.center,
          valueExtractor: (item) => item.vehicleNumber ?? (item.notes ?? '-'),
        ),
      );
    }

    // Vegetable Broker Specific
    if (config.hasField(ItemField.lotId)) {
      columns.add(
        InvoiceColumn(
          key: 'lot',
          labelIndex: 'lot',
          fallbackLabel: 'Lot ID',
          flex: 0.6,
          alignment: pw.Alignment.center,
          valueExtractor: (item) => item.lotId ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.grossWeight)) {
      columns.add(
        InvoiceColumn(
          key: 'gross',
          labelIndex: 'gross',
          fallbackLabel: 'Gross',
          flex: 0.6,
          alignment: pw.Alignment.centerRight,
          valueExtractor: (item) => item.grossWeight?.toStringAsFixed(2) ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.tareWeight)) {
      columns.add(
        InvoiceColumn(
          key: 'tare',
          labelIndex: 'tare',
          fallbackLabel: 'Tare',
          flex: 0.6,
          alignment: pw.Alignment.centerRight,
          valueExtractor: (item) => item.tareWeight?.toStringAsFixed(2) ?? '-',
        ),
      );
    }

    if (config.hasField(ItemField.netWeight)) {
      // Net weight is often the Quantity for billing, but if distinct field is enabled:
      columns.add(
        InvoiceColumn(
          key: 'net',
          labelIndex: 'net',
          fallbackLabel: 'Net Wt',
          flex: 0.7,
          alignment: pw.Alignment.centerRight,
          valueExtractor: (item) =>
              item.netWeight?.toStringAsFixed(2) ?? item.quantity.toString(),
        ),
      );
    }

    if (config.hasField(ItemField.commission)) {
      columns.add(
        InvoiceColumn(
          key: 'comm',
          labelIndex: 'commission',
          fallbackLabel: 'Comm',
          flex: 0.7,
          alignment: pw.Alignment.centerRight,
          valueExtractor: (item) => item.commission?.toStringAsFixed(2) ?? '-',
        ),
      );
    }

    // 4. Quantity (Always present)
    columns.add(
      InvoiceColumn(
        key: 'qty',
        labelIndex: 'qty',
        fallbackLabel: 'Qty',
        flex: 0.7,
        alignment: pw.Alignment.center,
        isMandatory: true,
        valueExtractor: (item) => item.quantity.toString(), // Format later
      ),
    );

    // 5. Unit (Optional based on space, usually good to have)
    // If not strictly required by business (e.g. restaurant often hides unit 'plate'), we can check config
    // But 'unit' is in requiredFields for most.
    columns.add(
      InvoiceColumn(
        key: 'unit',
        labelIndex: 'unit',
        fallbackLabel: 'Unit',
        flex: 0.6,
        alignment: pw.Alignment.center,
        valueExtractor: (item) => item.unit,
      ),
    );

    // 6. Rate (Price)
    columns.add(
      InvoiceColumn(
        key: 'rate',
        labelIndex: 'rate',
        fallbackLabel: config.priceLabel,
        flex: 1.0,
        alignment: pw.Alignment.centerRight,
        isMandatory: true,
        valueExtractor: (item) => item.unitPrice.toString(), // Format later
      ),
    );

    // 7. Tax (If enabled)
    if (showTax) {
      columns.add(
        InvoiceColumn(
          key: 'tax',
          labelIndex: 'tax',
          fallbackLabel: 'GST%',
          flex: 0.6,
          alignment: pw.Alignment.center,
          valueExtractor: (item) =>
              item.taxPercent != null ? '${item.taxPercent}%' : '-',
        ),
      );
    }

    // 8. Discount (If relevant)
    // Check if any item has discount > 0? Or just always show based on config?
    if (config.hasField(ItemField.discount)) {
      columns.add(
        InvoiceColumn(
          key: 'discount',
          labelIndex: 'discount',
          fallbackLabel: 'Disc',
          flex: 0.7,
          alignment: pw.Alignment.centerRight,
          valueExtractor: (item) => (item.discountAmount ?? 0) > 0
              ? item.discountAmount.toString()
              : '-',
        ),
      );
    }

    // 9. Amount (Total)
    columns.add(
      InvoiceColumn(
        key: 'amount',
        labelIndex: 'amount',
        fallbackLabel: 'Amount',
        flex: 1.2,
        alignment: pw.Alignment.centerRight,
        isMandatory: true,
        valueExtractor: (item) => item.total.toString(),
      ),
    );

    return columns;
  }
}
