/// AC verification for `worm schema:dump --prune` behaviour.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/cli/worm_command_runner.dart';

import '_fixtures.dart';

void _seedMigrationFiles(Directory projectRoot) {
  final migrationsDir = Directory('${projectRoot.path}/migrations')
    ..createSync(recursive: true);
  File(
    '${migrationsDir.path}/20260101_000000_create_users.dart',
  ).writeAsStringSync('// users');
  File(
    '${migrationsDir.path}/20260102_000000_create_posts.dart',
  ).writeAsStringSync('// posts');
}

void main() {
  group('worm schema:dump --prune', () {
    test('--prune --force deletes every .dart file under migrations/ '
        'and writes schema/schema_dump.dart', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      _seedMigrationFiles(harness.projectRoot);

      final runner = WormCommandRunner(harness.build());
      final code = await runner.run(<String>[
        'schema:dump',
        '--prune',
        '--force',
      ]);
      expect(code, 0);

      final remaining = Directory(
        '${harness.projectRoot.path}/migrations',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(remaining.length, 0);

      final dumpFile = File(
        '${harness.projectRoot.path}/schema/schema_dump.dart',
      );
      expect(dumpFile.existsSync(), isTrue);
      expect(dumpFile.readAsStringSync(), contains('schemaDump'));
    });

    test(
      '--prune without --force exits 1 with --force in the message',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        _seedMigrationFiles(harness.projectRoot);

        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>['schema:dump', '--prune']);
        expect(code, 1);
        expect(harness.err.toString(), contains('--force'));

        final remaining = Directory(
          '${harness.projectRoot.path}/migrations',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
        // No files were deleted because the command exited early.
        expect(remaining.length, 2);
      },
    );
  });
}
