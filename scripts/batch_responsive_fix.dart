#!/usr/bin/env dart
// ============================================================================
// BATCH RESPONSIVE FIX SCRIPT
// ============================================================================
// Applies responsive patterns to multiple screens automatically
// Run: dart scripts/batch_responsive_fix.dart
// ============================================================================

import 'dart:io';

void main() async {
  final fixes = BatchResponsiveFix();
  
  // High priority screens to fix
  final targets = [
    // Auth screens (high traffic)
    'lib/features/auth/presentation/screens/vendor_auth_screen.dart',
    'lib/features/auth/presentation/screens/customer_auth_screen.dart',
    
    // Inventory screens
    'lib/features/inventory/presentation/screens/product_management_screen.dart',
    'lib/features/inventory/presentation/screens/import_inventory_screen.dart',
    
    // Billing screens
    'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
    'lib/features/credit_notes/presentation/screens/credit_note_screen.dart',
    
    // Dashboard screens that need responsive updates
    'lib/features/clinic/screens/clinic_dashboard_screen.dart',
    'lib/features/computer_shop/presentation/screens/job_card_list_screen.dart',
    'lib/features/jewellery/presentation/screens/gold_rate_alert_screen.dart',
    'lib/features/restaurant/presentation/screens/menu_item_management_screen.dart',
    'lib/features/petrol_pump/presentation/screens/revenue_dashboard_screen.dart',
    
    // Academic coaching screens
    'lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart',
    'lib/features/academic_coaching/presentation/screens/ac_students_screen.dart',
    'lib/features/academic_coaching/presentation/screens/ac_fee_collection_screen.dart',
  ];
  
  for (final target in targets) {
    await fixes.applyFix(target);
  }
  
  fixes.printSummary();
}

class BatchResponsiveFix {
  int fixed = 0;
  int skipped = 0;
  int errors = 0;
  final List<String> errorFiles = [];

  Future<void> applyFix(String relativePath) async {
    final file = File('Dukan_x/$relativePath');
    if (!file.existsSync()) {
      print('SKIP: $relativePath (file not found)');
      skipped++;
      return;
    }

    try {
      var content = await file.readAsString();
      
      // Skip if already has responsive import
      if (content.contains("import 'package:dukanx/core/responsive/responsive.dart'")) {
        print('SKIP: $relativePath (already responsive)');
        skipped++;
        return;
      }

      // Add responsive import after last import or before first class
      final lastImportMatch = RegExp(r"^import .*;", multiLine: true).allMatches(content).lastOrNull;
      if (lastImportMatch != null) {
        final insertPos = lastImportMatch.end;
        content = content.substring(0, insertPos) + 
                  "\nimport 'package:dukanx/core/responsive/responsive.dart';" +
                  content.substring(insertPos);
      }

      // Fix common patterns
      content = _fixGridViewCrossAxisCount(content);
      content = _fixCommonHardcodedWidths(content);
      content = _fixHeaderFontSizes(content);

      await file.writeAsString(content);
      print('FIXED: $relativePath');
      fixed++;
    } catch (e) {
      print('ERROR: $relativePath - $e');
      errors++;
      errorFiles.add(relativePath);
    }
  }

  String _fixGridViewCrossAxisCount(String content) {
    // Pattern: crossAxisCount: 2, -> make responsive
    return content.replaceAllMapped(
      RegExp(r'crossAxisCount:\s*2\s*,'),
      (match) => '''crossAxisCount: responsiveValue<int>(context,
          mobile: 1,
          tablet: 2,
          desktop: 2,  // PRESERVED: Desktop uses exactly 2 as before
        ),''',
    );
  }

  String _fixCommonHardcodedWidths(String content) {
    // Fix common hardcoded SizedBox widths that cause overflow
    return content.replaceAllMapped(
      RegExp(r'SizedBox\(\s*width:\s*(300|320|350|400)\s*\)'),
      (match) => '''SizedBox(
          width: responsiveValue<double>(context,
            mobile: double.infinity,
            tablet: ${match.group(1)},
            desktop: ${match.group(1)},  // PRESERVED: Desktop uses exactly ${match.group(1)} as before
          ),''',
    );
  }

  String _fixHeaderFontSizes(String content) {
    // Fix common header font sizes while preserving desktop
    return content.replaceAllMapped(
      RegExp(r"style:\s*TextStyle\(\s*fontSize:\s*(20|22|24|28)([,.])"),
      (match) => '''style: TextStyle(
                  fontSize: responsiveValue<double>(context,
                    mobile: ${int.parse(match.group(1)!) - 4},
                    tablet: ${int.parse(match.group(1)!) - 2},
                    desktop: ${match.group(1)},  // PRESERVED: Desktop uses exactly ${match.group(1)} as before
                  )${match.group(2)}''',
    );
  }

  void printSummary() {
    print('');
    print('=' * 60);
    print('BATCH RESPONSIVE FIX SUMMARY');
    print('=' * 60);
    print('Fixed: $fixed screens');
    print('Skipped: $skipped screens');
    print('Errors: $errors screens');
    if (errorFiles.isNotEmpty) {
      print('Error files: ${errorFiles.join(", ")}');
    }
    print('=' * 60);
  }
}
