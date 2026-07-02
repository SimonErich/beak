import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:worm/src/cli/commands/gen_command.dart';
import 'package:worm/src/cli/process_runner.dart';

import '../_fixtures.dart';

/// Records the arguments of every spawned subprocess and returns a
/// canned exit code. Used in place of [DefaultProcessRunner] so the
/// test never touches a real process or the filesystem outside the
/// temp project root.
final class _FakeProcessRunner extends ProcessRunner {
  _FakeProcessRunner({this.exitCodes = const <int>[0]});

  /// Successive exit codes returned for each call (cycles back to
  /// the last entry once exhausted, mirroring a steady-state).
  final List<int> exitCodes;

  final List<_SpawnRecord> calls = <_SpawnRecord>[];

  @override
  Future<int> runSync(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  }) async {
    calls.add(
      _SpawnRecord(
        executable: executable,
        arguments: arguments,
        streamed: false,
        workingDirectory: workingDirectory,
      ),
    );
    return _nextExitCode();
  }

  @override
  Future<int> runStreamed(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  }) async {
    calls.add(
      _SpawnRecord(
        executable: executable,
        arguments: arguments,
        streamed: true,
        workingDirectory: workingDirectory,
      ),
    );
    return _nextExitCode();
  }

  int _nextExitCode() {
    if (calls.length <= exitCodes.length) {
      return exitCodes[calls.length - 1];
    }
    return exitCodes.last;
  }
}

final class _SpawnRecord {
  const _SpawnRecord({
    required this.executable,
    required this.arguments,
    required this.streamed,
    required this.workingDirectory,
  });
  final String executable;
  final List<String> arguments;
  final bool streamed;
  final String? workingDirectory;
}

Future<int> _runGen(
  TestHarness harness,
  GenCommand command,
  List<String> args,
) async {
  final runner = CommandRunner<int>('worm', 'test harness')
    ..addCommand(command);
  return (await runner.run(<String>['gen', ...args])) ?? 0;
}

void main() {
  group('worm gen', () {
    test('default invocation spawns `dart run build_runner build '
        '--delete-conflicting-outputs` and forwards the exit code', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final fake = _FakeProcessRunner(exitCodes: <int>[0]);
      final command = GenCommand(harness.build(), processRunner: fake);

      final code = await _runGen(harness, command, const <String>[]);

      expect(code, 0);
      expect(fake.calls, hasLength(1));
      final call = fake.calls.single;
      expect(call.executable, 'dart');
      expect(call.arguments, <String>[
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]);
      expect(call.streamed, isFalse);
      expect(call.workingDirectory, harness.projectRoot.path);
    });

    test('forwards a non-zero exit code from build_runner', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final fake = _FakeProcessRunner(exitCodes: <int>[7]);
      final command = GenCommand(harness.build(), processRunner: fake);

      final code = await _runGen(harness, command, const <String>[]);

      expect(code, 7);
    });

    test('--no-delete-conflicting-outputs omits the flag', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final fake = _FakeProcessRunner();
      final command = GenCommand(harness.build(), processRunner: fake);

      await _runGen(harness, command, const <String>[
        '--no-delete-conflicting-outputs',
      ]);

      expect(fake.calls.single.arguments, <String>[
        'run',
        'build_runner',
        'build',
      ]);
    });

    test('--clean runs `clean` then `build`', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final fake = _FakeProcessRunner(exitCodes: <int>[0, 0]);
      final command = GenCommand(harness.build(), processRunner: fake);

      final code = await _runGen(harness, command, const <String>['--clean']);

      expect(code, 0);
      expect(fake.calls, hasLength(2));
      expect(fake.calls[0].arguments, <String>['run', 'build_runner', 'clean']);
      expect(fake.calls[1].arguments, <String>[
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]);
      expect(fake.calls[0].streamed, isFalse);
      expect(fake.calls[1].streamed, isFalse);
    });

    test('--clean short-circuits when clean returns a non-zero code', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final fake = _FakeProcessRunner(exitCodes: <int>[2, 0]);
      final command = GenCommand(harness.build(), processRunner: fake);

      final code = await _runGen(harness, command, const <String>['--clean']);

      expect(code, 2);
      expect(
        fake.calls,
        hasLength(1),
        reason: 'build step should be skipped when clean fails',
      );
    });

    test(
      '--watch spawns `dart run build_runner watch` in streamed mode',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final fake = _FakeProcessRunner(exitCodes: <int>[0]);
        final command = GenCommand(harness.build(), processRunner: fake);

        final code = await _runGen(harness, command, const <String>['--watch']);

        expect(code, 0);
        expect(fake.calls, hasLength(1));
        expect(fake.calls.single.arguments, <String>[
          'run',
          'build_runner',
          'watch',
        ]);
        expect(fake.calls.single.streamed, isTrue);
      },
    );
  });
}
