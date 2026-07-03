import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  group('parse', () {
    test('reads KEY=VALUE pairs, skipping comments and blank lines', () {
      const content = '''
# database
DATABASE_URL=postgres://localhost/beak

PORT=8080
  # indented comment
''';
      expect(BeakEnv.parse(content), {
        'DATABASE_URL': 'postgres://localhost/beak',
        'PORT': '8080',
      });
    });

    test('strips an export prefix and whitespace around the separator', () {
      expect(BeakEnv.parse('export HOST = 127.0.0.1'), {'HOST': '127.0.0.1'});
    });

    test('strips matching surrounding quotes', () {
      expect(
        BeakEnv.parse('''
A="double quoted"
B='single quoted'
C="unbalanced'
'''),
        {'A': 'double quoted', 'B': 'single quoted', 'C': '"unbalanced\''},
      );
    });

    test('splits on the first separator only', () {
      expect(BeakEnv.parse('URL=postgres://u:p@h/db?a=b'), {
        'URL': 'postgres://u:p@h/db?a=b',
      });
    });

    test('rejects a line without a separator', () {
      expect(
        () => BeakEnv.parse('JUSTAKEY'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects an invalid key', () {
      expect(
        () => BeakEnv.parse('9LIVES=cat'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('loadFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('beak_env_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses an existing file', () {
      final file = File('${tempDir.path}/.env')
        ..writeAsStringSync('PORT=9090\n');
      expect(BeakEnv.loadFile(file.path), {'PORT': '9090'});
    });

    test('returns an empty map for a missing file', () {
      expect(BeakEnv.loadFile('${tempDir.path}/absent.env'), isEmpty);
    });
  });

  group('resolve', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('beak_env_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('overlays the process environment over file values', () {
      final file = File('${tempDir.path}/.env')
        ..writeAsStringSync('PORT=1111\nHOST=from-file\n');
      expect(
        BeakEnv.resolve(
          filePath: file.path,
          processEnvironment: {'PORT': '2222'},
        ),
        {'PORT': '2222', 'HOST': 'from-file'},
      );
    });

    test('reads the real process environment when none is injected', () {
      final resolved = BeakEnv.resolve(filePath: '${tempDir.path}/absent.env');
      expect(resolved, Platform.environment);
    });
  });
}
