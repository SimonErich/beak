import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('CliRunner', () {
    test('no arguments prints usage and exits with code 64', () async {
      final runner = CliRunner();
      final result = await runner.run(const <String>[]);
      expect(result.exitCode, 64);
      expect(result.output, contains('usage: worm'));
      expect(result.output, contains('gen'));
    });

    test('help prints usage and exits 0', () async {
      final runner = CliRunner();
      final result = await runner.run(const <String>['--help']);
      expect(result.exitCode, 0);
      expect(result.output, contains('Commands'));
    });

    test('gen invokes dart run build_runner build', () async {
      final captured = <List<String>>[];
      final runner = CliRunner(
        runner: (executable, arguments) async {
          captured.add(<String>[executable, ...arguments]);
          return ProcessResult(0, 0, 'ok', '');
        },
      );
      final result = await runner.run(const <String>['gen']);
      expect(result.exitCode, 0);
      expect(captured, isNotEmpty);
      expect(captured.single.first, 'dart');
      expect(captured.single, containsAll(<String>['run', 'build_runner']));
      expect(captured.single, contains('build'));
    });

    test('gen forwards extra args to build_runner', () async {
      final captured = <List<String>>[];
      final runner = CliRunner(
        runner: (executable, arguments) async {
          captured.add(<String>[executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
      );
      await runner.run(const <String>['gen', '--delete-conflicting-outputs']);
      expect(captured.single, contains('--delete-conflicting-outputs'));
    });

    test('gen propagates non-zero exit code on failure', () async {
      final runner = CliRunner(
        runner: (executable, arguments) async =>
            ProcessResult(0, 2, '', 'oops'),
      );
      final result = await runner.run(const <String>['gen']);
      expect(result.exitCode, 2);
      expect(result.output, contains('oops'));
    });

    test('unknown command returns 64 and helpful message', () async {
      final runner = CliRunner();
      final result = await runner.run(const <String>['zzzz']);
      expect(result.exitCode, 64);
      expect(result.output, contains('Unknown command'));
    });
  });
}
