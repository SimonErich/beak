import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/exception/migration_exception.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/migration/migration_dependency_sorter.dart';

final class _Mig extends Migration {
  const _Mig(this._name, {List<String> deps = const <String>[]}) : _deps = deps;
  final String _name;
  final List<String> _deps;
  @override
  String get name => _name;
  @override
  List<String> get dependsOn => _deps;
  @override
  Future<void> up(DatabaseAdapter adapter) async {}
  @override
  Future<void> down(DatabaseAdapter adapter) async {}
}

void main() {
  group('MigrationDependencySorter', () {
    test('returns declaration order when no dependencies declared', () {
      final sorted = MigrationDependencySorter.sort(const <Migration>[
        _Mig('a'),
        _Mig('b'),
        _Mig('c'),
      ]);
      expect(sorted.map((m) => m.name), <String>['a', 'b', 'c']);
    });

    test('moves a migration after its declared dependency', () {
      final sorted = MigrationDependencySorter.sort(const <Migration>[
        _Mig('child', deps: <String>['parent']),
        _Mig('parent'),
      ]);
      expect(sorted.map((m) => m.name), <String>['parent', 'child']);
    });

    test('rejects a dependency cycle naming both ends', () {
      expect(
        () => MigrationDependencySorter.sort(const <Migration>[
          _Mig('alpha', deps: <String>['omega']),
          _Mig('omega', deps: <String>['alpha']),
        ]),
        throwsA(
          isA<MigrationException>().having(
            (e) => e.toString(),
            'message',
            allOf(<Matcher>[contains('alpha'), contains('omega')]),
          ),
        ),
      );
    });

    test('rejects an unknown dependency by name', () {
      expect(
        () => MigrationDependencySorter.sort(const <Migration>[
          _Mig('child', deps: <String>['missing']),
        ]),
        throwsA(
          isA<MigrationException>().having(
            (e) => e.toString(),
            'message',
            contains('missing'),
          ),
        ),
      );
    });
  });
}
