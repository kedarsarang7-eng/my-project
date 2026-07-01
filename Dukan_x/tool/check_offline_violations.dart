// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final directoriesToCheck = ['lib/screens', 'lib/features'];
  final bannedPatterns = [
    'package:cloud_firestore/cloud_firestore.dart',
    'FirestoreService',
    'SyncService', // Legacy sync service
  ];

  int violationCount = 0;

  print('🔍 Scanning for Offline Mode Violations...');

  for (final dirPath in directoriesToCheck) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = entity.readAsStringSync();
        for (final pattern in bannedPatterns) {
          if (content.contains(pattern)) {
            print('❌ Violation in ${entity.path}: Found "$pattern"');
            violationCount++;
          }
        }
      }
    }
  }

  if (violationCount > 0) {
    print('\n🚨 FOUND $violationCount VIOLATIONS');
    print('The build failed because UI code is accessing Firestore directly.');
    print('Please refactor to use BillsRepository or CustomersRepository.');
    exit(1);
  } else {
    print('\n✅ ZERO VIOLATIONS FOUND. Offline Mode Enforced.');
    exit(0);
  }
}
