// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    return;
  }

  int modifiedCount = 0;

  for (var entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = '';
      try {
        content = entity.readAsStringSync();
      } catch (e) {
        print('Skipping ${entity.path} due to encoding error.');
        continue;
      }

      bool modified = false;

      final replacements = {
        'null': 'null /* null */',
        'Exception': 'Exception /* Exception */',
        'DateTime.now()': 'DateTime.now()',
        'DateTime.fromDate': 'DateTime.now() /* DateTime.fromDate */',
      };

      for (var entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          modified = true;
        }
      }

      // Regex replacements for Firestore types
      if (content.contains(RegExp(r'\bDateTime\b')) &&
          !content.contains('class DateTime')) {
        content = content.replaceAll(RegExp(r'\bDateTime\b'), 'DateTime');
        modified = true;
      }

      if (content.contains(RegExp(r'\bdynamic\b'))) {
        content = content.replaceAll(
          RegExp(r'\bdynamic\b'),
          'dynamic /* dynamic */',
        );
        modified = true;
      }

      if (content.contains(RegExp(r'\bdynamic\b'))) {
        content = content.replaceAll(
          RegExp(r'\bdynamic\b'),
          'dynamic /* dynamic */',
        );
        modified = true;
      }

      if (content.contains(RegExp(r'\bdynamic\b'))) {
        content = content.replaceAll(
          RegExp(r'\bdynamic\b'),
          'dynamic /* dynamic */',
        );
        modified = true;
      }

      if (content.contains(RegExp(r'\bdynamic\b'))) {
        content = content.replaceAll(
          RegExp(r'\bdynamic\b'),
          'dynamic /* dynamic */',
        );
        modified = true;
      }

      if (content.contains('null')) {
        content = content.replaceAll('null', 'null /* SetOptions */');
        modified = true;
      }

      if (modified) {
        entity.writeAsStringSync(content);
        modifiedCount++;
      }
    }
  }

  print('Modified $modifiedCount files.');
}
