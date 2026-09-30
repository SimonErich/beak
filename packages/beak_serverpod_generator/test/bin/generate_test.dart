import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs `bin/generate.dart` the way `dart run beak_serverpod_generator:generate`
/// does, against the fixture libraries.
Future<ProcessResult> _generate(File config) =>
    Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/generate.dart',
      '--config',
      config.path,
      '--root',
      Directory.current.path,
    ]);

void main() {
  late Directory work;
  late File config;
  late File output;

  setUp(() {
    work = Directory.systemTemp.createTempSync('beak_generate_');
    config = File(p.join(work.path, 'beak_serverpod.yaml'));
    output = File('test/fixtures/generated_by_bin.g.dart');
  });

  tearDown(() {
    work.deleteSync(recursive: true);
    if (output.existsSync()) output.deleteSync();
  });

  String library(String fixture) =>
      Uri.file(p.absolute('test/fixtures/$fixture')).toString();

  test(
    'says it generated the file once, and that it is up to date after',
    () async {
      config.writeAsStringSync('''
library: ${library('models.dart')}
types: [Input]
output: test/fixtures/generated_by_bin.g.dart
''');

      final first = await _generate(config);
      expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
      expect(first.stdout, contains('Generated '));
      final written = output.lastModifiedSync();
      final content = output.readAsStringSync();

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final second = await _generate(config);

      expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
      expect(second.stdout, contains('Up to date '));
      expect(second.stdout, isNot(contains('Generated ')));
      expect(output.lastModifiedSync(), written, reason: 'left untouched');
      expect(output.readAsStringSync(), content);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('reads the client class from the config', () async {
    config.writeAsStringSync('''
library: ${library('read_resources.dart')}
models: [EntryView]
client: ReadClient
output: test/fixtures/generated_by_bin.g.dart
''');

    final result = await _generate(config);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(output.readAsStringSync(), contains('ReadClient'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('--client overrides the config', () async {
    config.writeAsStringSync('''
library: ${library('read_resources.dart')}
models: [EntryView]
client: Missing
output: test/fixtures/generated_by_bin.g.dart
''');

    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/generate.dart',
      '--config',
      config.path,
      '--root',
      Directory.current.path,
      '--client',
      'ReadClient',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
