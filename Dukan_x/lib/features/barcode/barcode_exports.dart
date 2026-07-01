// ignore_for_file: ambiguous_export
// ============================================================================
// BARCODE FEATURE — BARREL EXPORTS
// ============================================================================
// Single import for all barcode-related classes, widgets, and integrations.
//
// Usage:
//   import 'package:dukan_x/features/barcode/barcode_exports.dart';
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

// --- Models ---
export 'models/barcode_scan_result.dart';

// --- Services ---
export 'services/barcode_lookup_service.dart';
export 'services/offline_scan_queue_service.dart';

// --- Widgets ---
export 'widgets/desktop_usb_scanner.dart';
export 'widgets/imei_scanner_widget.dart';
export 'widgets/serial_scanner_widget.dart';
export 'widgets/isbn_scanner_widget.dart';
export 'widgets/auto_parts_scanner_widget.dart';
export 'widgets/clothing_variant_scanner_widget.dart';
export 'widgets/wholesale_bulk_scanner_widget.dart';
export 'widgets/barcode_label_printer.dart';

// --- Integration ---
export 'integration/barcode_integration_mixin.dart';
export 'integration/bill_creation_barcode_integration.dart';
export 'integration/purchase_barcode_integration.dart';
export 'integration/stock_adjustment_barcode_integration.dart';
export 'integration/stock_entry_barcode_integration.dart';
export 'integration/delivery_challan_barcode_integration.dart';
export 'integration/inventory_count_barcode_integration.dart';
export 'integration/stock_transfer_barcode_integration.dart';
export 'integration/returns_barcode_integration.dart';

// --- Screens ---
export 'presentation/screens/quick_bill_with_barcode_screen.dart';
