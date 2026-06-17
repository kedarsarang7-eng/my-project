#!/usr/bin/env dart
// ============================================================================
// APPLY RESPONSIVE PATTERNS TO ALL SCREENS
// ============================================================================

import 'dart:io';

void main() async {
  print('Applying responsive patterns to all screens...');
  
  final allScreens = <File>[];
  final featuresDir = Directory('Dukan_x/lib/features');
  
  await for (final entity in featuresDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_screen.dart')) {
      allScreens.add(entity);
    }
  }
  
  int gridFixed = 0;
  int fontFixed = 0;
  int paddingFixed = 0;
  int totalChecked = 0;
  
  for (final screen in allScreens) {
    try {
      var content = await screen.readAsString();
      totalChecked++;
      
      // Skip if no responsive import (not yet converted)
      if (!content.contains("import 'package:dukanx/core/responsive/responsive.dart'")) {
        continue;
      }
      
      // Fix GridView.count patterns
      if (content.contains('crossAxisCount: 2') || content.contains('crossAxisCount: 3')) {
        content = content.replaceAll(
          'crossAxisCount: 2,',
          'crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),',
        );
        content = content.replaceAll(
          'crossAxisCount: 3,',
          'crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 3),',
        );
        gridFixed++;
      }
      
      // Fix common header font sizes while preserving desktop
      final fontPatterns = [
        ['fontSize: 28,', 'fontSize: responsiveValue<double>(context, mobile: 22, tablet: 24, desktop: 28),'],
        ['fontSize: 26,', 'fontSize: responsiveValue<double>(context, mobile: 20, tablet: 22, desktop: 26),'],
        ['fontSize: 24,', 'fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),'],
        ['fontSize: 22,', 'fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),'],
        ['fontSize: 20,', 'fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),'],
      ];
      
      for (final pattern in fontPatterns) {
        if (content.contains(pattern[0])) {
          content = content.replaceAll(pattern[0], pattern[1]);
          fontFixed++;
        }
      }
      
      // Fix large padding on mobile
      if (content.contains('padding: const EdgeInsets.all(24)')) {
        content = content.replaceAll(
          'padding: const EdgeInsets.all(24)',
          'padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24))'
        );
        paddingFixed++;
      }
      
      await screen.writeAsString(content);
      
    } catch (e) {
      print('ERROR: ${screen.path} - $e');
    }
  }
  
  print('');
  print('=' * 60);
  print('RESPONSIVE PATTERNS APPLIED');
  print('=' * 60);
  print('Screens checked: $totalChecked');
  print('GridViews fixed: $gridFixed');
  print('Font sizes fixed: $fontFixed');
  print('Padding fixed: $paddingFixed');
  print('=' * 60);
}
