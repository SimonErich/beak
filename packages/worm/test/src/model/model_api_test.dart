/// Model convenience API: update / forceDelete / replicate /
/// getOriginalValue / toMap.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

/// A model that overrides [replicate] using [replicatedAttributes].
final class _Widget extends Model {
  _Widget();

  @override
  String get tableName => 'widgets';

  @override
  bool get usesTimestamps => false;

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};

  @override
  _Widget replicate({List<String> except = const <String>[]}) {
    final clone = _Widget();
    replicatedAttributes(except: except).forEach(clone.setAttribute);
    return clone;
  }
}

void main() {
  late InMemoryAdapter adapter;

  Future<List<Map<String, Object?>>> rows() =>
      adapter.select(const QueryDescriptor(table: 'tests'));

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

  group('update', () {
    test('fills then saves', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        fillableOverride: const <String>['name'],
      )..setAttribute('id', 1);
      await model.save();

      await model.update(<String, Object?>{'name': 'Bob'});
      expect((await rows()).single['name'], 'Bob');
    });
  });

  group('forceDelete', () {
    test('hard-deletes a plain model', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1);
      await model.save();
      expect(await model.forceDelete(), isTrue);
      expect(await rows(), isEmpty);
    });
  });

  group('replicate', () {
    test('clones attributes minus the primary key, exists=false', () {
      final original = _Widget()
        ..setAttribute('id', 1)
        ..setAttribute('name', 'A')
        ..markPersisted();

      final clone = original.replicate();
      expect(clone.getAttribute('name'), 'A');
      expect(clone.getAttribute('id'), isNull);
      expect(clone.exists, isFalse);
    });

    test('honors the except list', () {
      final original = _Widget()
        ..setAttribute('id', 1)
        ..setAttribute('name', 'A')
        ..setAttribute('color', 'red')
        ..markPersisted();

      final clone = original.replicate(except: const <String>['color']);
      expect(clone.getAttribute('name'), 'A');
      expect(clone.getAttribute('color'), isNull);
    });

    test('the base default throws when not overridden', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1);
      expect(model.replicate, throwsA(isA<UnsupportedOperationException>()));
    });
  });

  group('getOriginalValue', () {
    test('returns the typed pre-modification value', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();

      model.setAttribute('name', 'Bob');
      expect(model.getOriginalValue(const Field<String>('name')), 'Alice');
      // Untouched field → null.
      expect(model.getOriginalValue(const Field<int>('age')), isNull);
    });
  });

  group('toMap', () {
    test('default includes column-backed fields', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      expect(model.toMap(), containsPair('name', 'Alice'));
    });

    test('only restricts to a whitelist', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      expect(model.toMap(only: <String>{'name'}), <String, Object?>{
        'name': 'Alice',
      });
    });

    test('hidden removes named keys', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('secret', 'x');
      expect(
        model.toMap(hidden: <String>{'secret'}),
        isNot(contains('secret')),
      );
    });
  });
}
