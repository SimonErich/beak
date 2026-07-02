import 'package:test/test.dart';
import 'package:worm/src/cli/worm_command_runner.dart';

import '_fixtures.dart';

/// The 15 commands the CLI registers, in the order they appear in
/// the spec command reference table. Acts as a single source of
/// truth for every iteration test below — keep this in sync with
/// [WormCommandRunner]'s `addCommand` calls.
const List<String> _expectedCommands = <String>[
  'init',
  'make:model',
  'make:migration',
  'make:seeder',
  'make:factory',
  'make:observer',
  'migrate',
  'migrate:rollback',
  'migrate:status',
  'migrate:fresh',
  'migrate:refresh',
  'db:seed',
  'schema:dump',
  'model:show',
  'gen',
];

void main() {
  group('WormCommandRunner registration', () {
    test('registers exactly 15 commands matching the spec', () {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      // CommandRunner auto-adds an implicit `help` command; exclude
      // it for the 15-count assertion.
      final registered = runner.commands.keys
          .where((name) => name != 'help')
          .toSet();
      expect(registered, hasLength(15));
      expect(registered, equals(_expectedCommands.toSet()));
    });

    test('global help output lists every registered command name', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      final code = await runner.run(const <String>['--help']);
      expect(code, 0);
      final help = harness.out.toString();
      for (final name in _expectedCommands) {
        expect(
          help,
          contains(name),
          reason: 'global help should advertise "$name"',
        );
      }
    });
  });

  group('WormCommandRunner exit-code contract', () {
    test('every command exits 0 when invoked with --help', () async {
      for (final name in _expectedCommands) {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final runner = WormCommandRunner(harness.build());

        final code = await runner.run(<String>[name, '--help']);

        expect(
          code,
          0,
          reason: '`worm $name --help` should exit 0; it returned $code',
        );
        expect(
          harness.out.toString(),
          isNotEmpty,
          reason: '`worm $name --help` should write usage to stdout',
        );
      }
    });

    test('unknown commands exit with code 2', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      for (final bogus in const <String>[
        'this-does-not-exist',
        'make:nope',
        'migrate:typo',
      ]) {
        harness.err.clear();
        final code = await runner.run(<String>[bogus]);

        expect(
          code,
          2,
          reason: '`worm $bogus` should exit 2; it returned $code',
        );
        expect(
          harness.err.toString(),
          isNotEmpty,
          reason: 'unknown command should write a diagnostic to stderr',
        );
      }
    });
  });
}
