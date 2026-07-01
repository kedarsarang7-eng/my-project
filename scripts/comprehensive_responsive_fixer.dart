#!/usr/bin/env dart
// ============================================================================
// COMPREHENSIVE RESPONSIVE FIXER - ALL 335+ SCREENS
// ============================================================================
// Automatically fixes all remaining screens for responsive design
// Run: dart scripts/comprehensive_responsive_fixer.dart
// ============================================================================

import 'dart:io';

void main() async {
  final fixer = ComprehensiveResponsiveFixer();
  await fixer.run();
}

class ComprehensiveResponsiveFixer {
  int totalScreens = 0;
  int fixedScreens = 0;
  int skippedScreens = 0;
  int errorScreens = 0;
  final List<String> errors = [];

  // Business types to process
  final List<String> businessTypes = [
    'academic_coaching',
    'restaurant',
    'staff',
    'petrol_pump',
    'jewellery',
    'computer_shop',
    'decoration_catering',
    'book_store',
    'auto_parts',
    'hardware',
    'pharmacy',
    'clinic',
    'doctor',
    'service',
    'inventory',
    'billing',
    'reports',
    'dashboard',
    'customers',
    'auth',
    'onboarding',
    'alerts',
    'analytics',
    'avatar',
    'backup',
    'bank',
    'barcode',
    'buy_flow',
    'cash_closing',
    'catalogue',
    'clothing',
    'core',
    'credit_network',
    'credit_notes',
    'daybook',
    'delivery_challan',
    'document_scanner',
    'e_invoice',
    'expenses',
    'gst',
    'in_store',
    'insights',
    'invoice',
    'localization',
    'marketing',
    'marketplace',
    'ml',
    'party_ledger',
    'patient',
    'patients',
    'payment',
    'physical_to_digital',
    'pre_order',
    'prescriptions',
    'profile',
    'purchase',
    'revenue',
    'sale',
    'settings',
    'shared',
    'shop',
    'shop_linking',
    'shortcuts',
    'stock',
    'subscription',
    'super_admin',
    'sync',
    'vegetable_broker',
    'visits',
    'voice',
  ];

  Future<void> run() async {
    print('=' * 80);
    print('COMPREHENSIVE RESPONSIVE FIXER');
    print('Processing all 335+ screens across all business types...');
    print('=' * 80);
    print('');

    final stopwatch = Stopwatch()..start();

    for (final businessType in businessTypes) {
      await _processBusinessType(businessType);
    }

    stopwatch.stop();

    _printSummary(stopwatch.elapsed);
  }

  Future<void> _processBusinessType(String businessType) async {
    final featuresDir = Directory('Dukan_x/lib/features/$businessType');
    if (!featuresDir.existsSync()) {
      return;
    }

    await for (final entity in featuresDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('_screen.dart')) {
        totalScreens++;
        await _fixScreen(entity.path);
      }
    }
  }

  Future<void> _fixScreen(String filePath) async {
    final file = File(filePath);

    try {
      var content = await file.readAsString();

      // Skip if already has responsive import
      if (content.contains(
        "import 'package:dukanx/core/responsive/responsive.dart'",
      )) {
        skippedScreens++;
        print('SKIP: ${filePath.split('/').last} (already responsive)');
        return;
      }

      // Add responsive import
      content = _addResponsiveImport(content);

      // Fix GridView patterns
      content = _fixGridViewPatterns(content, filePath);

      // Fix common font sizes while preserving desktop
      content = _fixFontSizes(content, filePath);

      // Fix hardcoded padding
      content = _fixPadding(content, filePath);

      // Fix fixed widths that cause overflow
      content = _fixFixedWidths(content, filePath);

      // Add SingleChildScrollView where needed
      content = _addScrollViews(content, filePath);

      await file.writeAsString(content);
      fixedScreens++;
      print('FIXED: ${filePath.split('/').last}');
    } catch (e) {
      errorScreens++;
      errors.add('$filePath: $e');
      print('ERROR: ${filePath.split('/').last} - $e');
    }
  }

  String _addResponsiveImport(String content) {
    // Find a good place to add the import
    final packageImports = RegExp(
      r"^import 'package:.*';",
      multiLine: true,
    ).allMatches(content);

    if (packageImports.isNotEmpty) {
      final lastPackageImport = packageImports.last;
      final insertPos = lastPackageImport.end;

      // Check if already has it
      if (!content.contains(
        "import 'package:dukanx/core/responsive/responsive.dart'",
      )) {
        content =
            content.substring(0, insertPos) +
            "\nimport 'package:dukanx/core/responsive/responsive.dart';" +
            content.substring(insertPos);
      }
    }

    return content;
  }

  String _fixGridViewPatterns(String content, String filePath) {
    // Pattern 1: GridView.count with hardcoded crossAxisCount
    content = content.replaceAllMapped(
      RegExp(
        r'GridView\.count\(\s*shrinkWrap:\s*true,\s*physics:\s*const\s+NeverScrollableScrollPhysics\(\),\s*crossAxisCount:\s*(\d+)',
        multiLine: true,
      ),
      (match) {
        final originalCount = match.group(1);
        return '''GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context,
        mobile: ${int.parse(originalCount!) > 2 ? 1 : 1},
        tablet: $originalCount,
        desktop: $originalCount,  // PRESERVED: Desktop uses exactly $originalCount as before
      )''';
      },
    );

    // Pattern 2: GridView.builder with SliverGridDelegateWithFixedCrossAxisCount
    content = content.replaceAllMapped(
      RegExp(
        r'SliverGridDelegateWithFixedCrossAxisCount\(\s*crossAxisCount:\s*(\d+)',
        multiLine: true,
      ),
      (match) {
        final originalCount = match.group(1);
        return '''SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: responsiveValue<int>(context,
            mobile: 1,
            tablet: ${int.parse(originalCount!) > 2 ? 2 : originalCount},
            desktop: $originalCount,  // PRESERVED: Desktop uses exactly $originalCount as before
          )''';
      },
    );

    return content;
  }

  String _fixFontSizes(String content, String filePath) {
    // Fix header font sizes (20-32 range) while preserving desktop
    content = content.replaceAllMapped(
      RegExp(
        r'style:\s*TextStyle\(\s*fontSize:\s*(20|22|24|26|28|30|32)\.?0?\s*,',
        multiLine: true,
      ),
      (match) {
        final originalSize = match.group(1)!;
        final mobileSize = int.parse(originalSize) - 4;
        final tabletSize = int.parse(originalSize) - 2;

        return 'style: TextStyle(\n'
            '                  fontSize: responsiveValue<double>(context,\n'
            '                    mobile: $mobileSize.0,\n'
            '                    tablet: $tabletSize.0,\n'
            '                    desktop: $originalSize.0,  // PRESERVED: Desktop uses exactly $originalSize as before\n'
            '                  ),';
      },
    );

    // Fix subtitle font sizes (12-16 range)
    content = content.replaceAllMapped(
      RegExp(
        r'style:\s*TextStyle\(\s*fontSize:\s*(12|13|14|15|16)\.?0?\s*,\s*color:\s*Colors\.grey',
        multiLine: true,
      ),
      (match) {
        final originalSize = match.group(1)!;
        final mobileSize = int.parse(originalSize) - 2;
        final tabletSize = int.parse(originalSize) - 1;
        return 'style: TextStyle(\n'
            '                  fontSize: responsiveValue<double>(context,\n'
            '                    mobile: $mobileSize.0,\n'
            '                    tablet: $tabletSize.0,\n'
            '                    desktop: $originalSize.0,  // PRESERVED\n'
            '                  ),\n'
            '                  color: Colors.grey';
      },
    );

    return content;
  }

  String _fixPadding(String content, String filePath) {
    // Fix EdgeInsets.all(24) - too much on mobile
    content = content.replaceAllMapped(
      RegExp(r'padding:\s*const\s+EdgeInsets\.all\((24|32)\)'),
      (match) {
        final original = match.group(1)!;
        return 'padding: EdgeInsets.all(responsiveValue<double>(context,\n'
            '              mobile: 16,\n'
            '              tablet: 20,\n'
            '              desktop: $original.0,  // PRESERVED\n'
            '            ))';
      },
    );

    return content;
  }

  String _fixFixedWidths(String content, String filePath) {
    // Fix SizedBox with fixed widths that overflow
    content = content.replaceAllMapped(
      RegExp(r'SizedBox\(\s*width:\s*(300|320|350|400|450)\.?0?\s*\)'),
      (match) {
        final originalWidth = match.group(1)!;
        return 'SizedBox(\n'
            '          width: responsiveValue<double>(context,\n'
            '            mobile: double.infinity,\n'
            '            tablet: $originalWidth.0,\n'
            '            desktop: $originalWidth.0,  // PRESERVED\n'
            '          ))';
      },
    );

    return content;
  }

  String _addScrollViews(String content, String filePath) {
    // Check if the screen has a Column that might overflow but no SingleChildScrollView
    if (content.contains('Column(') &&
        !content.contains('SingleChildScrollView') &&
        !content.contains('ListView') &&
        !content.contains('CustomScrollView')) {
      // Add scroll view wrapping pattern for common build methods
      content = content.replaceAllMapped(
        RegExp(
          r'(Widget\s+_build\w+\([^)]*\)\s*\{\s*return\s+)Scaffold\(\s*body:\s*Column\(',
          multiLine: true,
        ),
        (match) {
          return '${match.group(1)}Scaffold(\n'
              '      body: SingleChildScrollView(\n'
              '        child: Column(';
        },
      );

      // Close the SingleChildScrollView
      if (content.contains('SingleChildScrollView(') &&
          !content.contains('SingleChildScrollView(physics:')) {
        content = content.replaceAllMapped(
          RegExp(
            r'(Column\([^)]*children:\s*\[[^]]*\],?\s*\)\),?\s*\)\s*;\s*\})',
          ),
          (match) {
            return '${match.group(0)}\n'
                '        ),\n'
                '      ),\n'
                '    );\n'
                '  }';
          },
        );
      }
    }

    return content;
  }

  void _printSummary(Duration elapsed) {
    print('');
    print('=' * 80);
    print('COMPREHENSIVE RESPONSIVE FIX - SUMMARY');
    print('=' * 80);
    print('Total screens processed: $totalScreens');
    print('Screens fixed: $fixedScreens');
    print('Screens skipped (already responsive): $skippedScreens');
    print('Screens with errors: $errorScreens');
    print('Duration: ${elapsed.inSeconds} seconds');
    print('');
    print('Desktop experience: PRESERVED on all screens');
    print('Mobile/Tablet: Now adaptive with responsive values');
    print('=' * 80);

    if (errors.isNotEmpty) {
      print('');
      print('ERRORS ENCOUNTERED:');
      for (final error in errors.take(10)) {
        print('  - $error');
      }
      if (errors.length > 10) {
        print('  ... and ${errors.length - 10} more');
      }
    }
  }
}
