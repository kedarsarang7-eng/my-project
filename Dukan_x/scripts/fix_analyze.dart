// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('analyze_clean.txt');
  if (!file.existsSync()) return;

  List<String> lines = [];
  try {
    lines = file.readAsLinesSync();
  } catch (e) {
    // Handling UTF-16 LE or other formats from PowerShell
    final bytes = file.readAsBytesSync();
    // basic ascii string conversion or skipping
    String content = String.fromCharCodes(bytes).replaceAll('\x00', '');
    lines = content.split('\n');
  }
  final Set<String> filesToFix = {};

  for (var line in lines) {
    if (line.contains('error - ') || line.contains('warning - ')) {
      final parts = line.split(' - ');
      if (parts.length >= 2) {
        final pathPart = parts[1].split(':');
        if (pathPart.isNotEmpty) {
          filesToFix.add(pathPart[0].trim());
        }
      }
    }
  }

  int modifiedCount = 0;
  for (var path in filesToFix) {
    final f = File(path);
    if (!f.existsSync() || !path.endsWith('.dart')) continue;

    String content = '';
    try {
      content = f.readAsStringSync();
    } catch (_) {
      continue;
    }

    bool modified = false;

    // Fix remaining Firebase classes
    final fixes = {
      'FirebaseFirestore.instance': 'null',
      'FirebaseFirestore': 'dynamic',
      'DocumentSnapshot': 'dynamic',
      'QuerySnapshot': 'dynamic',
      'DocumentReference': 'dynamic',
      'CollectionReference': 'dynamic',
      'FieldValue.serverTimestamp()': 'DateTime.now()',
      'FieldValue': 'dynamic',
      'SetOptions(merge: true)': 'null',
      'FirebaseException': 'Exception',
      'FirebaseAppCheck.instance': 'null',
      'ReCaptchaV3Provider': 'dynamic',
      'AndroidDebugProvider': 'dynamic',
      'AndroidPlayIntegrityProvider': 'dynamic',
      'AppleDebugProvider': 'dynamic',
      'AppleAppAttestProvider': 'dynamic',
      'Timestamp': 'DateTime',
      'FirebaseCrashlytics.instance': 'null',
      'FirebaseMessaging.instance': 'null',
      'FirebaseStorage.instance': 'null',
    };

    for (var entry in fixes.entries) {
      if (content.contains(entry.key)) {
        // Broad replace but ensure we don't break string literals if possible.
        // For simplicity in this sweeping cleanup, we do a raw replace.
        content = content.replaceAll(entry.key, entry.value);
        modified = true;
      }
    }

    // Fix imports that might have been missed or have aliases
    final regexes = [
      RegExp(r"import 'package:cloud_firestore/.*?;\n?"),
      RegExp(r"import 'package:firebase_.*?;\n?"),
    ];

    for (var r in regexes) {
      if (r.hasMatch(content)) {
        content = content.replaceAll(r, '');
        modified = true;
      }
    }

    if (modified) {
      f.writeAsStringSync(content);
      modifiedCount++;
    }
  }

  print('Fixed $modifiedCount files from analyze results.');
}
