#!/usr/bin/env dart
// ============================================================================
// RESPONSIVE SCREEN AUDIT SCRIPT
// ============================================================================
// Identifies all screens lacking responsive design patterns
// Run: dart scripts/responsive_screen_audit.dart
// ============================================================================

import 'dart:io';

void main() async {
  final featuresDir = Directory('Dukan_x/lib/features');
  if (!featuresDir.existsSync()) {
    print('ERROR: Run from project root directory');
    exit(1);
  }

  final audit = ResponsiveAudit();
  await audit.run(featuresDir);
  audit.printReport();
}

class ScreenFile {
  final String path;
  final String businessType;
  final String content;

  ScreenFile(this.path, this.businessType, this.content);

  bool get hasResponsiveImport => content.contains("import 'package:dukanx/core/responsive/responsive.dart'") ||
                                   content.contains('responsive.dart');
  bool get usesResponsiveValue => content.contains('responsiveValue');
  bool get usesAdaptiveScroll => content.contains('AdaptiveScroll');
  bool get usesBoundedBox => content.contains('BoundedBox');
  bool get usesMediaQuery => content.contains('MediaQuery');
  bool get usesLayoutBuilder => content.contains('LayoutBuilder');
  bool get hasHardcodedDimensions {
    // Check for common hardcoded patterns
    final patterns = [
      RegExp(r'width:\s*\d+\.?\d*[,\s}]'),  // width: 400
      RegExp(r'height:\s*\d+\.?\d*[,\s}]'), // height: 300
      RegExp(r'fontSize:\s*\d+\.?\d*[,\s}]'), // fontSize: 16
      RegExp(r'padding:\s*EdgeInsets\.all\(\d+\.?\d*\)'), // padding: EdgeInsets.all(16)
      RegExp(r'sizedBox.*width.*\d+'), // SizedBox(width: 100)
      RegExp(r'sizedBox.*height.*\d+'), // SizedBox(height: 50)
    ];
    return patterns.any((p) => p.hasMatch(content));
  }

  int get responsiveScore {
    int score = 0;
    if (hasResponsiveImport) score += 3;
    if (usesResponsiveValue) score += 3;
    if (usesAdaptiveScroll) score += 2;
    if (usesBoundedBox) score += 2;
    if (usesMediaQuery) score += 1;
    if (usesLayoutBuilder) score += 1;
    if (!hasHardcodedDimensions) score += 2;
    return score;
  }

  String get riskLevel {
    if (responsiveScore >= 8) return 'LOW';
    if (responsiveScore >= 4) return 'MEDIUM';
    if (responsiveScore >= 1) return 'HIGH';
    return 'CRITICAL';
  }
}

class ResponsiveAudit {
  final List<ScreenFile> screens = [];
  final Map<String, List<ScreenFile>> byBusinessType = {};

  Future<void> run(Directory featuresDir) async {
    await for (final entity in featuresDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('_screen.dart')) {
        final content = await entity.readAsString();
        final parts = entity.path.split('/');
        final businessType = parts.length > 2 ? parts[2] : 'unknown';
        final screen = ScreenFile(entity.path, businessType, content);
        screens.add(screen);
        byBusinessType.putIfAbsent(businessType, () => []).add(screen);
      }
    }
  }

  void printReport() {
    print('=' * 80);
    print('RESPONSIVE SCREEN AUDIT REPORT');
    print('=' * 80);
    print('');
    print('TOTAL SCREENS AUDITED: ${screens.length}');
    print('');

    // Summary by risk
    final critical = screens.where((s) => s.riskLevel == 'CRITICAL').length;
    final high = screens.where((s) => s.riskLevel == 'HIGH').length;
    final medium = screens.where((s) => s.riskLevel == 'MEDIUM').length;
    final low = screens.where((s) => s.riskLevel == 'LOW').length;

    print('RISK DISTRIBUTION:');
    print('  CRITICAL (No responsive code): $critical screens');
    print('  HIGH     (Minimal responsive): $high screens');
    print('  MEDIUM   (Partial responsive): $medium screens');
    print('  LOW      (Well responsive):    $low screens');
    print('');

    // By business type
    print('BY BUSINESS TYPE:');
    final sortedTypes = byBusinessType.keys.toList()..sort();
    for (final type in sortedTypes) {
      final typeScreens = byBusinessType[type]!;
      final criticalCount = typeScreens.where((s) => s.riskLevel == 'CRITICAL').length;
      final percent = (criticalCount / typeScreens.length * 100).round();
      print('  ${type.padRight(20)}: ${typeScreens.length.toString().padLeft(3)} screens ($percent% CRITICAL)');
    }
    print('');

    // Critical screens list
    print('CRITICAL SCREENS (No Responsive Implementation):');
    print('-' * 80);
    final criticalScreens = screens.where((s) => s.riskLevel == 'CRITICAL').toList();
    for (final screen in criticalScreens.take(50)) {
      print('  ${screen.path}');
    }
    if (criticalScreens.length > 50) {
      print('  ... and ${criticalScreens.length - 50} more');
    }
    print('');

    // Recommendations
    print('RECOMMENDATIONS:');
    print('-' * 80);
    print('1. IMMEDIATE: Wrap critical screens with AdaptiveScroll to prevent overflow');
    print('2. HIGH: Replace hardcoded dimensions with responsiveValue() calls');
    print('3. MEDIUM: Add LayoutBuilder to complex layouts');
    print('4. LOW: Add visual regression tests for tablet viewports');
    print('');
  }
}
