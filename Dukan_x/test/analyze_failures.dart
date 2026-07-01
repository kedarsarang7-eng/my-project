import 'dart:convert';
import 'dart:io';

void main() async {
  print('Running flutter test --reporter=json to find failing/skipped tests...');
  final process = await Process.start(
    'flutter',
    ['test', '--reporter=json'],
    runInShell: true,
  );

  final Map<int, Map<String, dynamic>> tests = {};
  final Map<int, String> suites = {};
  final List<Map<String, dynamic>> failures = [];
  final List<Map<String, dynamic>> skipped = [];

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final type = data['type'] as String;

      if (type == 'suite') {
        final suite = data['suite'] as Map<String, dynamic>;
        suites[suite['id'] as int] = suite['path'] as String;
      } else if (type == 'testStart') {
        final test = data['test'] as Map<String, dynamic>;
        tests[test['id'] as int] = test;
      } else if (type == 'error') {
        final testId = data['testID'] as int;
        final error = data['error'] as String;
        final isFailure = data['isFailure'] as bool;
        final test = tests[testId];
        final suiteId = test?['suiteID'] as int?;
        final suitePath = suites[suiteId];
        failures.add({
          'name': test?['name'] ?? 'Unknown test',
          'path': suitePath ?? 'Unknown path',
          'error': error,
          'isFailure': isFailure,
        });
      } else if (type == 'testDone') {
        final testId = data['testID'] as int;
        final result = data['result'] as String?;
        final wasSkipped = data['skipped'] as bool? ?? false;
        final test = tests[testId];
        final suiteId = test?['suiteID'] as int?;
        final suitePath = suites[suiteId];

        if (wasSkipped) {
          skipped.add({
            'name': test?['name'] ?? 'Unknown test',
            'path': suitePath ?? 'Unknown path',
          });
        }
      }
    } catch (_) {}
  });

  process.stderr.transform(utf8.decoder).listen(stdout.write);

  final exitCode = await process.exitCode;
  print('\nTest run finished with exit code $exitCode.');

  final report = StringBuffer();
  report.writeln('# Test Failures and Skipped Tests Report');
  report.writeln('Generated on: ${DateTime.now().toIso8601String()}\n');

  report.writeln('## Summary');
  report.writeln('- **Failing Tests:** ${failures.length}');
  report.writeln('- **Skipped Tests:** ${skipped.length}\n');

  if (failures.isNotEmpty) {
    report.writeln('## Failing Tests');
    // Group by file path
    final groupedFailures = <String, List<Map<String, dynamic>>>{};
    for (final f in failures) {
      groupedFailures.putIfAbsent(f['path'] as String, () => []).add(f);
    }

    for (final entry in groupedFailures.entries) {
      report.writeln('### `${entry.key}`');
      for (final f in entry.value) {
        report.writeln('- **Test:** ${f['name']}');
        report.writeln('  **Error:**');
        report.writeln('  ```');
        report.writeln('  ${f['error'].toString().trim().replaceAll('\n', '\n  ')}');
        report.writeln('  ```');
      }
      report.writeln();
    }
  }

  if (skipped.isNotEmpty) {
    report.writeln('## Skipped Tests');
    final groupedSkipped = <String, List<String>>{};
    for (final s in skipped) {
      groupedSkipped.putIfAbsent(s['path'] as String, () => []).add(s['name'] as String);
    }

    for (final entry in groupedSkipped.entries) {
      report.writeln('### `${entry.key}`');
      for (final name in entry.value) {
        report.writeln('- $name');
      }
      report.writeln();
    }
  }

  final reportFile = File('test_failures_report.md');
  await reportFile.writeAsString(report.toString());
  print('Saved failure report to test_failures_report.md');
}
