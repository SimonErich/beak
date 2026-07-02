/// Mass assignment protection.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/mass_assignment_exception.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

void main() {
  group('mass assignment', () {
    test('without fillable or guarded, every field is accepted', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..fill(<String, Object?>{'name': 'Alice', 'role': 'admin'});
      expect(model.getAttribute('name'), 'Alice');
      expect(model.getAttribute('role'), 'admin');
    });

    test('guarded fields are silently rejected by default', () {
      final model = TestModel(
        tableNameOverride: 'tests',
        guardedOverride: const <String>['role'],
      )..fill(<String, Object?>{'name': 'Alice', 'role': 'admin'});
      expect(model.getAttribute('name'), 'Alice');
      expect(model.getAttribute('role'), isNull);
    });

    test('fillable whitelist limits accepted fields', () {
      final model = TestModel(
        tableNameOverride: 'tests',
        fillableOverride: const <String>['name'],
      )..fill(<String, Object?>{'name': 'Alice', 'role': 'admin'});
      expect(model.getAttribute('name'), 'Alice');
      expect(model.getAttribute('role'), isNull);
    });

    test('strict mode throws MassAssignmentException', () {
      final model = TestModel(
        tableNameOverride: 'tests',
        guardedOverride: const <String>['role'],
        strictOverride: true,
      );
      expect(
        () => model.fill(<String, Object?>{'role': 'admin'}),
        throwsA(
          isA<MassAssignmentException>().having(
            (e) => e.field,
            'field',
            'role',
          ),
        ),
      );
    });

    test('fill marks each accepted field dirty', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..fill(<String, Object?>{'name': 'Alice', 'age': 30});
      expect(model.dirtyFields, containsAll(<String>['name', 'age']));
    });
  });

  group('global preventSilentMassAssignment', () {
    setUp(() async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventSilentMassAssignment: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': adapter},
      );
    });

    tearDown(Worm.reset);

    test('a non-strict model throws when the global flag is set', () {
      final model = TestModel(
        tableNameOverride: 'tests',
        guardedOverride: const <String>['role'],
      );
      expect(
        () => model.fill(<String, Object?>{'role': 'admin'}),
        throwsA(isA<MassAssignmentException>()),
      );
    });

    test('Worm.unsafe relaxes the global flag back to silent skip', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        guardedOverride: const <String>['role'],
      );
      await Worm.unsafe(() async {
        model.fill(<String, Object?>{'name': 'Alice', 'role': 'admin'});
      });
      expect(model.getAttribute('name'), 'Alice');
      expect(model.getAttribute('role'), isNull);
    });
  });
}
