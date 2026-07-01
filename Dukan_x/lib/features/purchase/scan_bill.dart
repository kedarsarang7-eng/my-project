// ============================================================================
// Scan Bill Feature — Barrel Export
// ============================================================================
// OCR-based Purchase Entry for DukanX
// 
// Usage:
//   import 'package:dukan_x/features/purchase/scan_bill.dart';
//   
//   // Navigate to scan bill flow
//   Navigator.pushNamed(context, ScanBillRoutes.imagePicker, 
//     arguments: {'verticalType': 'grocery'});
// ============================================================================

import 'package:flutter/material.dart';
import 'presentation/screens/scan_bill_image_picker_screen.dart';
import 'presentation/screens/scan_bill_processing_screen.dart';

// Models
export 'models/scan_bill_models.dart';

// Services
export 'services/scan_bill_api_client.dart';
export 'services/purchase_receipt_pdf.dart';
export 'services/scan_bill_offline_queue.dart';

// Workers
export 'workers/scan_bill_sync_worker.dart';

// Providers
export 'providers/scan_bill_session_provider.dart';

// Screens
export 'presentation/screens/scan_bill_image_picker_screen.dart';
export 'presentation/screens/scan_bill_processing_screen.dart';
export 'presentation/screens/scan_bill_review_screen.dart';
export 'presentation/screens/scan_bill_supplier_screen.dart';
export 'presentation/screens/purchase_entries_list_screen.dart';

/// Route names for the scan bill flow
class ScanBillRoutes {
  ScanBillRoutes._();

  static const String base = '/purchase/scan-bill';
  static const String imagePicker = '$base/picker';
  static const String processing = '$base/processing';
  static const String review = '$base/review';
  static const String supplier = '$base/supplier';
}

/// Helper class to launch the scan bill flow
class ScanBillNavigator {
  ScanBillNavigator._();

  /// Start the scan bill flow
  static Future<void> start(BuildContext context, {required String verticalType}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanBillImagePickerScreen(verticalType: verticalType),
      ),
    );
  }

  /// Start with a specific image (e.g., from gallery)
  static Future<void> startWithImage(
    BuildContext context, {
    required String verticalType,
    required String imagePath,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanBillProcessingScreen(
          verticalType: verticalType,
          skipToMatching: false,
        ),
      ),
    );
  }
}
