// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) return;

  int modifiedCount = 0;

  for (var entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = '';
      try {
        content = entity.readAsStringSync();
      } catch (_) {
        continue;
      }

      bool modified = false;

      // Fix `null` type inference errors
      if (content.contains('null /* FirebaseFirestore.instance */')) {
        content = content.replaceAll(
          'null /* FirebaseFirestore.instance */',
          '(null as dynamic)',
        );
        modified = true;
      }

      if (content.contains('null /* SetOptions */')) {
        content = content.replaceAll(
          'null /* SetOptions */',
          '(null as dynamic)',
        );
        modified = true;
      }

      // Fix Query typing
      final queryRegex = RegExp(r'\bQuery\s+([a-zA-Z0-9_]+)\s*=');
      if (queryRegex.hasMatch(content)) {
        content = content.replaceAllMapped(
          queryRegex,
          (m) => 'dynamic ${m.group(1)} =',
        );
        modified = true;
      }

      // Fix .toDate() calls (which were Timestamp methods)
      if (content.contains('.toDate()')) {
        content = content.replaceAll('.toDate()', '');
        modified = true;
      }

      // Fix FieldValue.increment and FieldValue.delete leftovers
      if (content.contains('dynamic.delete()')) {
        content = content.replaceAll('dynamic.delete()', 'null');
        modified = true;
      }
      if (content.contains('dynamic.increment')) {
        content = content.replaceAllMapped(
          RegExp(r'dynamic\.increment\((.*?)\)'),
          (m) => m.group(1)!,
        );
        modified = true;
      }
      if (content.contains('dynamic.arrayUnion')) {
        content = content.replaceAllMapped(
          RegExp(r'dynamic\.arrayUnion\(\[(.*?)\]\)'),
          (m) => m.group(1)!,
        );
        modified = true;
      }
      if (content.contains('dynamic.arrayRemove')) {
        content = content.replaceAllMapped(
          RegExp(r'dynamic\.arrayRemove\(\[(.*?)\]\)'),
          (m) => 'null',
        );
        modified = true;
      }

      // Some explicit places might use `Query ` as a return type
      final queryReturnRegex = RegExp(r'\bQuery\b(?!Snapshot)(?!\.)');
      if (queryReturnRegex.hasMatch(content) &&
          !content.contains('class Query')) {
        // Only replace if it's used as a type, but careful not to replace it if it's part of a string.
        // For simplicity:
        content = content.replaceAll(
          RegExp(r'\bQuery\b(?!Snapshot)(?!\.)(?!\s*\()'),
          'dynamic',
        );
        modified = true;
      }

      // Check for remaining DataGuard usages missing imports (just in case)
      if (content.contains('DataGuard.') &&
          !content.contains('data_guard.dart')) {
        content =
            "import 'package:dukanx/core/data/data_guard.dart';\n$content";
        modified = true;
      }

      if (modified) {
        entity.writeAsStringSync(content);
        modifiedCount++;
      }
    }
  }

  print('Second sweep modified $modifiedCount files.');
}
