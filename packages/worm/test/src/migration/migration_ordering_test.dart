/// Migration dependsOn ordering and cycle detection.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/migration_exception.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/migration/migration_dependency_sorter.dart';
import 'package:worm/src/migration/migration_runner.dart';

final class _NoopMigration extends Migration {
  const _NoopMigration({
    required String name,
    List<String> dependsOn = const <String>[],
  }) : _name = name,
       _dependsOn = dependsOn;

  final String _name;
  final List<String> _dependsOn;

  @override
  String get name => _name;

  @override
  List<String> get dependsOn => _dependsOn;

  @override
  Future<void> up(DatabaseAdapter adapter) async {}

  @override
  Future<void> down(DatabaseAdapter adapter) async {}
}

void main() {
  group('MigrationDependencySorter', () {
    test('reorders a migration after its declared dependency', () {
      const earlier = _NoopMigration(name: 'earlier');
      const later = _NoopMigration(
        name: 'later',
        dependsOn: <String>['earlier'],
      );
      // Registered in the WRONG order: dependent first.
      final sorted = MigrationDependencySorter.sort(const <Migration>[
        later,
        earlier,
      ]);
      expect(sorted.map((m) => m.name), <String>['earlier', 'later']);
    });

    test('preserves registration order when dependsOn is empty', () {
      const a = _NoopMigration(name: 'a');
      const b = _NoopMigration(name: 'b');
      const c = _NoopMigration(name: 'c');
      final sorted = MigrationDependencySorter.sort(const <Migration>[a, b, c]);
      expect(sorted.map((m) => m.name), <String>['a', 'b', 'c']);
    });

    test('throws MigrationException naming both nodes in a cycle', () {
      const a = _NoopMigration(name: 'A', dependsOn: <String>['B']);
      const b = _NoopMigration(name: 'B', dependsOn: <String>['A']);
      expect(
        () => MigrationDependencySorter.sort(const <Migration>[a, b]),
        throwsA(
          predicate<Object?>(
            (e) =>
                e is MigrationException &&
                e.message.contains("'A'") &&
                e.message.contains("'B'"),
            'MigrationException naming both A and B',
          ),
        ),
      );
    });

    test('rejects an unknown dependency reference', () {
      const a = _NoopMigration(name: 'a', dependsOn: <String>['ghost']);
      expect(
        () => MigrationDependencySorter.sort(const <Migration>[a]),
        throwsA(isA<MigrationException>()),
      );
    });
  });

  group('MigrationRunner sorts via MigrationDependencySorter', () {
    test('runs dependsOn migrations before their dependents', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      const earlier = _NoopMigration(name: 'earlier_migration');
      const later = _NoopMigration(
        name: 'later_migration',
        dependsOn: <String>['earlier_migration'],
      );
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[later, earlier],
      );
      final applied = await runner.migrate();
      expect(applied, <String>['earlier_migration', 'later_migration']);
    });

    test('cycle prevents construction and surfaces a clear error', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      const a = _NoopMigration(name: 'A', dependsOn: <String>['B']);
      const b = _NoopMigration(name: 'B', dependsOn: <String>['A']);
      expect(
        () => MigrationRunner(
          adapter: adapter,
          migrations: const <Migration>[a, b],
        ),
        throwsA(
          predicate<Object?>(
            (e) =>
                e is MigrationException &&
                e.message.contains("'A'") &&
                e.message.contains("'B'"),
          ),
        ),
      );
    });
  });
}
