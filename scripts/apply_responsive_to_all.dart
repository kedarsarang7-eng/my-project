#!/usr/bin/env dart
// ============================================================================
// APPLY RESPONSIVE TO ALL SCREENS - SIMPLIFIED VERSION
// ============================================================================

import 'dart:io';

void main() async {
  print('Finding all screen files...');
  
  final allScreens = <File>[];
  final featuresDir = Directory('Dukan_x/lib/features');
  
  if (!featuresDir.existsSync()) {
    print('ERROR: Dukan_x/lib/features not found');
    exit(1);
  }
  
  await for (final entity in featuresDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_screen.dart')) {
      allScreens.add(entity);
    }
  }
  
  print('Found ${allScreens.length} screen files');
  print('');
  
  int fixed = 0;
  int skipped = 0;
  int errors = 0;
  
  for (final screen in allScreens) {
    try {
      var content = await screen.readAsString();
      
      // Skip if already has responsive import
      if (content.contains("import 'package:dukanx/core/responsive/responsive.dart'")) {
        skipped++;
        continue;
      }
      
      // Add responsive import after other imports
      final lastImport = content.lastIndexOf("import '");
      if (lastImport != -1) {
        final endOfLine = content.indexOf(';', lastImport);
        if (endOfLine != -1) {
          content = content.substring(0, endOfLine + 1) + 
                    "\nimport 'package:dukanx/core/responsive/responsive.dart';" +
                    content.substring(endOfLine + 1);
        }
      }
      
      await screen.writeAsString(content);
      fixed++;
      print('FIXED: ${screen.path.split('/').last}');
      
    } catch (e) {
      errors++;
      print('ERROR: ${screen.path} - $e');
    }
  }
  
  print('');
  print('=' * 60);
  print('SUMMARY');
  print('=' * 60);
  print('Total screens: ${allScreens.length}');
  print('Fixed: $fixed');
  print('Skipped: $skipped');
  print('Errors: $errors');
  print('=' * 60);
}
