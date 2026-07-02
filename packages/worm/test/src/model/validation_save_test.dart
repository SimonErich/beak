/// Validation auto-fires during Active Record save.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/validation_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/validation/rules/min_length_rule.dart';
import 'package:worm/src/validation/rules/required_rule.dart';
import 'package:worm/src/validation/rules/unique_rule.dart';
import 'package:worm/src/validation/validation_rule.dart';

import '_fixtures.dart';

/// Identity passthrough that lets a `const` map literal (with its
/// `const` keys and rule lists) be used where a non-const
/// `Map<Field, …>` is needed — [Field] overrides `==`, so the map
/// itself cannot be `const`.
Map<Field<Object?>, List<ValidationRule>> _rules(
  Map<Field<Object?>, List<ValidationRule>> rules,
) => rules;

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'tests'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('validation on save', () {
    test('a required field that is empty cancels the insert', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
          const Field<Object?>('name'): const <ValidationRule>[Required()],
        }),
      )..setAttribute('id', 1);

      await expectLater(model.save, throwsA(isA<ValidationException>()));
      expect(model.exists, isFalse);
      final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
      expect(rows, isEmpty);
    });

    test('a valid model saves normally', () async {
      final model =
          TestModel(
              tableNameOverride: 'tests',
              rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
                const Field<Object?>('name'): const <ValidationRule>[
                  Required(),
                  MinLength(2),
                ],
              }),
            )
            ..setAttribute('id', 1)
            ..setAttribute('name', 'Alice');

      expect(await model.save(), isTrue);
      expect(model.exists, isTrue);
    });

    test('models without rules pay no validation cost and save', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1);
      expect(await model.save(), isTrue);
    });

    test('afterValidate does not fire when validation throws', () async {
      final log = HookLog();
      final model = TestModel(
        tableNameOverride: 'tests',
        log: log,
        rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
          const Field<Object?>('name'): const <ValidationRule>[Required()],
        }),
      )..setAttribute('id', 1);

      await expectLater(model.save, throwsA(isA<ValidationException>()));
      expect(log.events, contains('beforeValidate'));
      expect(log.events, isNot(contains('afterValidate')));
      expect(log.events, isNot(contains('beforeSave')));
    });

    test('update path validates only dirty fields', () async {
      // A clean field stays untouched while a different field is edited
      // validly — the update must succeed because clean fields are not
      // revalidated.
      final model =
          TestModel(
              tableNameOverride: 'tests',
              rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
                const Field<Object?>('name'): const <ValidationRule>[
                  Required(),
                ],
                const Field<Object?>('nickname'): const <ValidationRule>[
                  Required(),
                ],
              }),
            )
            ..setAttribute('id', 1)
            ..setAttribute('name', 'Alice')
            ..setAttribute('nickname', 'Al');
      await model.save();

      model.setAttribute('name', 'Alice B.');
      expect(await model.save(), isTrue);
    });

    test('update path rejects an invalid dirty field', () async {
      final model =
          TestModel(
              tableNameOverride: 'tests',
              rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
                const Field<Object?>('name'): const <ValidationRule>[
                  Required(),
                ],
              }),
            )
            ..setAttribute('id', 1)
            ..setAttribute('name', 'Alice');
      await model.save();

      model.setAttribute('name', '');
      await expectLater(model.save, throwsA(isA<ValidationException>()));
    });

    test('async Unique rule runs during save and rejects duplicates', () async {
      final first = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await first.save();

      final second =
          TestModel(
              tableNameOverride: 'tests',
              rulesOverride: _rules(<Field<Object?>, List<ValidationRule>>{
                const Field<Object?>('name'): <ValidationRule>[
                  Unique(adapter: adapter, table: 'tests', column: 'name'),
                ],
              }),
            )
            ..setAttribute('id', 2)
            ..setAttribute('name', 'Alice');

      await expectLater(second.save, throwsA(isA<ValidationException>()));
    });
  });
}
