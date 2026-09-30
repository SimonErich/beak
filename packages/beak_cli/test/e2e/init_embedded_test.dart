@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// Embedding the panel in a Flutter app that already exists.
///
/// `beak init` edits the app's pubspec, writes an entrypoint of its own and
/// runs `flutter pub get` and `beak prepare`. What has to hold is that the
/// result is a real, clean project: it analyzes with nothing to report, its
/// migrations run, and the app's own `lib/main.dart` is exactly what it was.
///
/// Tagged `e2e` for its cost, a real `flutter pub get` and `flutter analyze`.
void main() {
  test(
    'an existing app gains a panel that analyzes clean and migrates',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final app = Directory.systemTemp.createTempSync('beak_init_e2e_');
      addTearDown(() => app.deleteSync(recursive: true));

      const appMain = '''
import 'package:flutter/widgets.dart';

void main() => runApp(const SizedBox());
''';
      File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
description: An existing Flutter app.
publish_to: none

environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'

dependencies:
  # The framework.
  flutter:
    sdk: flutter
''');
      File('${app.path}/lib/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(appMain);
      File('${app.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
''');

      final out = StringBuffer();
      final environment = BeakCliEnvironment(
        out: out,
        rootDirectory: app,
        now: () => DateTime.utc(2026, 9, 28, 10, 15),
        probe: (host, port) async => false,
        runProcess: (executable, arguments, {workingDirectory}) async {
          final ProcessResult result = await Process.run(
            executable,
            arguments,
            workingDirectory: workingDirectory,
          );
          return result.exitCode;
        },
      );

      expect(
        await createBeakRunner(
          environment,
        ).run(['init', '--example', '--beak-path', repoRoot.path]),
        0,
        reason: '$out',
      );

      expect(File('${app.path}/lib/main.dart').readAsStringSync(), appMain);
      expect(
        File('${app.path}/pubspec.yaml').readAsStringSync(),
        contains('# The framework.'),
      );

      final ProcessResult analyzed = await Process.run('flutter', [
        'analyze',
      ], workingDirectory: app.path);
      expect(
        analyzed.exitCode,
        0,
        reason: 'flutter analyze:\n${analyzed.stdout}\n${analyzed.stderr}',
      );

      final ProcessResult migrated = await Process.run('dart', [
        'run',
        'bin/migrate.dart',
        'migrate',
      ], workingDirectory: app.path);
      expect(
        migrated.exitCode,
        0,
        reason: 'migrate:\n${migrated.stdout}\n${migrated.stderr}',
      );

      final checks = await diagnose(
        environment,
        readSchema: (url, {String schema = 'public'}) async => [],
      );
      expect(
        checks.where((check) => check.status == BeakCheckStatus.fail),
        isEmpty,
        reason: checks.map((check) => check.label).join('\n'),
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
