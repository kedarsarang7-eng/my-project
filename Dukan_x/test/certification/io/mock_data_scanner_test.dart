/// Example tests for mock-data classification in [MockDataScanner].
///
/// 1. Clean build: temp directory simulating a Release_Build with clean files
///    → assert clean=true, zero occurrences.
/// 2. Detected build: files with mock data patterns (placeholder credentials,
///    stub responses, fake classes) → assert clean=false, occurrences detected,
///    one defect per occurrence.
/// 3. Documentation comments are NOT flagged.
/// 4. Timeout handling: very short timeout with many files.
/// 5. Non-existent build path → failure result.
///
/// **Validates: Requirements 15.1, 15.2**
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../core/defect.dart';
import 'mock_data_scanner.dart';

void main() {
  late Directory tempDir;
  late MockDataScanner scanner;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mock_data_scanner_test_');
    scanner = MockDataScanner();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Clean build → clean=true, zero occurrences (Req 15.1)', () {
    test(
      'Release_Build with only clean source files classifies as clean',
      () async {
        // Create clean source files that don't trigger any detection rules.
        final libDir = Directory('${tempDir.path}/lib');
        libDir.createSync(recursive: true);

        File('${libDir.path}/main.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DukanX',
      home: const HomePage(),
    );
  }
}
''');

        File('${libDir.path}/calculator.dart').writeAsStringSync('''
class Calculator {
  double add(double a, double b) => a + b;
  double subtract(double a, double b) => a - b;
  double multiply(double a, double b) => a * b;
}
''');

        File('${libDir.path}/config.json').writeAsStringSync('''
{
  "appName": "DukanX",
  "version": "1.0.0",
  "apiEndpoint": "https://api.production.example.com"
}
''');

        final build = BuildArtifact(
          rootPath: tempDir.path,
          sourceModules: ['lib/main.dart', 'lib/calculator.dart'],
          assets: [],
          configFiles: ['lib/config.json'],
        );

        final result = await scanner.scan(build);

        expect(result.clean, isTrue);
        expect(result.occurrences, isEmpty);
        expect(result.defects, isEmpty);
        expect(result.scanCompleted, isTrue);
        expect(result.errorMessage, isNull);
      },
    );

    test('empty source list classifies as clean', () async {
      final build = BuildArtifact(
        rootPath: tempDir.path,
        sourceModules: [],
        assets: [],
        configFiles: [],
      );

      final result = await scanner.scan(build);

      expect(result.clean, isTrue);
      expect(result.occurrences, isEmpty);
      expect(result.scanCompleted, isTrue);
    });
  });

  group(
    'Detected build → clean=false, per-occurrence defect (Req 15.1, 15.2)',
    () {
      test('placeholder credentials are detected', () async {
        final libDir = Directory('${tempDir.path}/lib');
        libDir.createSync(recursive: true);

        File('${libDir.path}/auth_service.dart').writeAsStringSync('''
class AuthService {
  static const defaultEmail = "test@test.com";
  static const defaultPassword = "password123";

  Future<bool> login(String email, String password) async {
    return email == defaultEmail && password == defaultPassword;
  }
}
''');

        final build = BuildArtifact(
          rootPath: tempDir.path,
          sourceModules: ['lib/auth_service.dart'],
          assets: [],
          configFiles: [],
        );

        final result = await scanner.scan(build);

        expect(result.clean, isFalse);
        expect(result.occurrences, isNotEmpty);
        expect(result.scanCompleted, isTrue);

        // Should detect both placeholder credentials.
        final credOccurrences = result.occurrences
            .where((o) => o.kind == MockDataKind.placeholderCredential)
            .toList();
        expect(credOccurrences.length, greaterThanOrEqualTo(2));

        // One defect per occurrence.
        expect(result.defects.length, equals(result.occurrences.length));
      });

      test('stubbed responses are detected', () async {
        final libDir = Directory('${tempDir.path}/lib');
        libDir.createSync(recursive: true);

        File('${libDir.path}/api_client.dart').writeAsStringSync('''
class ApiClient {
  Map<String, dynamic> getMockResponse() {
    return {"status": "ok", "data": []};
  }

  String stubbedResponse = '{"items": []}';
}
''');

        final build = BuildArtifact(
          rootPath: tempDir.path,
          sourceModules: ['lib/api_client.dart'],
          assets: [],
          configFiles: [],
        );

        final result = await scanner.scan(build);

        expect(result.clean, isFalse);
        expect(result.occurrences, isNotEmpty);

        final stubOccurrences = result.occurrences
            .where((o) => o.kind == MockDataKind.stubbedResponse)
            .toList();
        expect(stubOccurrences, isNotEmpty);

        // Defects are release-blocking.
        for (final defect in result.defects) {
          expect(defect.severity, equals(Severity.critical));
          expect(defect.status, equals(ResolutionStatus.open));
        }
      });

      test('in-memory fake classes are detected', () async {
        final libDir = Directory('${tempDir.path}/lib');
        libDir.createSync(recursive: true);

        File('${libDir.path}/repositories.dart').writeAsStringSync('''
class FakeUserRepository {
  final List<Map<String, dynamic>> users = [];

  void addUser(Map<String, dynamic> user) {
    users.add(user);
  }
}

class FakePaymentService {
  bool processPayment(double amount) => true;
}
''');

        final build = BuildArtifact(
          rootPath: tempDir.path,
          sourceModules: ['lib/repositories.dart'],
          assets: [],
          configFiles: [],
        );

        final result = await scanner.scan(build);

        expect(result.clean, isFalse);

        final fakeOccurrences = result.occurrences
            .where((o) => o.kind == MockDataKind.inMemoryFake)
            .toList();
        expect(fakeOccurrences, isNotEmpty);

        // Each occurrence generates exactly one defect.
        expect(result.defects.length, equals(result.occurrences.length));

        // Defect IDs are unique.
        final ids = result.defects.map((d) => d.id).toSet();
        expect(ids.length, equals(result.defects.length));
      });

      test(
        'multiple mock patterns in a single file all produce defects',
        () async {
          final libDir = Directory('${tempDir.path}/lib');
          libDir.createSync(recursive: true);

          File('${libDir.path}/mixed.dart').writeAsStringSync('''
class FakeAuthClient {
  final apiKey = "sk_test_abc123";
  final sampleData = [1, 2, 3];
  String stubbedResponse = "ok";
}
''');

          final build = BuildArtifact(
            rootPath: tempDir.path,
            sourceModules: ['lib/mixed.dart'],
            assets: [],
            configFiles: [],
          );

          final result = await scanner.scan(build);

          expect(result.clean, isFalse);
          // Multiple different kinds detected.
          final kinds = result.occurrences.map((o) => o.kind).toSet();
          expect(kinds.length, greaterThanOrEqualTo(2));
          // One defect per occurrence.
          expect(result.defects.length, equals(result.occurrences.length));
        },
      );
    },
  );

  group('Documentation comments are NOT flagged (Req 15.1)', () {
    test('lines starting with /// are skipped', () async {
      final libDir = Directory('${tempDir.path}/lib');
      libDir.createSync(recursive: true);

      File('${libDir.path}/documented.dart').writeAsStringSync('''
/// This service replaces the old FakeAuthService implementation.
/// It no longer uses password123 or test@test.com.
/// The stubbed_response pattern was removed in v2.
/// See also: sample_data migration notes.
class RealAuthService {
  Future<bool> login(String email, String password) async {
    return true;
  }
}
''');

      final build = BuildArtifact(
        rootPath: tempDir.path,
        sourceModules: ['lib/documented.dart'],
        assets: [],
        configFiles: [],
      );

      final result = await scanner.scan(build);

      expect(
        result.clean,
        isTrue,
        reason: 'Documentation comments should not trigger detection',
      );
      expect(result.occurrences, isEmpty);
      expect(result.defects, isEmpty);
    });

    test('lines starting with // are skipped', () async {
      final libDir = Directory('${tempDir.path}/lib');
      libDir.createSync(recursive: true);

      File('${libDir.path}/commented.dart').writeAsStringSync('''
class ProductService {
  // Previously used mockResponse for testing, now removed.
  // password123 was the old default — replaced with env-based auth.
  Future<List<String>> getProducts() async {
    return [];
  }
}
''');

      final build = BuildArtifact(
        rootPath: tempDir.path,
        sourceModules: ['lib/commented.dart'],
        assets: [],
        configFiles: [],
      );

      final result = await scanner.scan(build);

      expect(
        result.clean,
        isTrue,
        reason: 'Single-line comments should not trigger detection',
      );
      expect(result.occurrences, isEmpty);
    });
  });

  group('Timeout handling (Req 15.1)', () {
    test('short timeout with many files results in scan failure', () async {
      final libDir = Directory('${tempDir.path}/lib');
      libDir.createSync(recursive: true);

      // Create many files to ensure the scan takes nonzero time.
      final filePaths = <String>[];
      for (int i = 0; i < 500; i++) {
        final fileName = 'module_$i.dart';
        final filePath = '${libDir.path}/$fileName';
        // Write content that requires processing.
        File(filePath).writeAsStringSync(
          '''
class Module$i {
  final String name = "module_$i";
  final int value = $i;
  void process() {
    for (int j = 0; j < 100; j++) {
      // processing logic
    }
  }
}
''' *
              10,
        ); // Repeat content to make files larger.
        filePaths.add('lib/$fileName');
      }

      final build = BuildArtifact(
        rootPath: tempDir.path,
        sourceModules: filePaths,
        assets: [],
        configFiles: [],
      );

      // Use Duration.zero to guarantee timeout on the first file check.
      final result = await scanner.scan(build, timeout: Duration.zero);

      expect(result.scanCompleted, isFalse);
      expect(result.clean, isFalse, reason: 'Failed scan → no-go → not clean');
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('timed out'));
    });
  });

  group('Non-existent build path → failure result (Req 15.6)', () {
    test('non-existent root path returns failure with error message', () async {
      final build = BuildArtifact(
        rootPath: '${tempDir.path}/non_existent_build_dir',
        sourceModules: ['lib/main.dart'],
        assets: [],
        configFiles: [],
      );

      final result = await scanner.scan(build);

      expect(result.scanCompleted, isFalse);
      expect(result.clean, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('does not exist'));
      expect(
        result.defects,
        isNotEmpty,
        reason: 'Failure should produce a defect',
      );
    });
  });
}
