import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';

const _age = ComparableField<int>('age');

Future<InMemoryAdapter> _adapter({bool seed = true}) async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  if (seed) {
    await adapter.insertMany(
      const InsertManyDescriptor(
        table: 'users',
        rows: <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'age': 30},
          <String, Object?>{'id': 2, 'age': 25},
          <String, Object?>{'id': 3, 'age': 40},
          <String, Object?>{'id': 4, 'age': 35},
        ],
      ),
    );
  }
  return adapter;
}

void main() {
  group('count', () {
    test('returns 0 for an empty table', () async {
      final adapter = await _adapter(seed: false);
      final c = await adapter.count(
        const AggregateDescriptor.count(table: 'users'),
      );
      expect(c, 0);
    });

    test('returns the full count when no where clause', () async {
      final adapter = await _adapter();
      final c = await adapter.count(
        const AggregateDescriptor.count(table: 'users'),
      );
      expect(c, 4);
    });

    test('applies where to the count', () async {
      final adapter = await _adapter();
      final c = await adapter.count(
        AggregateDescriptor.count(table: 'users', where: _age.gte(30)),
      );
      expect(c, 3);
    });
  });

  group('sum', () {
    test('returns null for an empty result set', () async {
      final adapter = await _adapter(seed: false);
      final total = await adapter.sum(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'age',
        ),
      );
      expect(total, isNull);
    });

    test('returns the arithmetic sum when rows match', () async {
      final adapter = await _adapter();
      final total = await adapter.sum(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'age',
        ),
      );
      expect(total, 130);
    });
  });

  group('avg', () {
    test('returns null for an empty result set', () async {
      final adapter = await _adapter(seed: false);
      final average = await adapter.avg(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.avg,
          column: 'age',
        ),
      );
      expect(average, isNull);
    });

    test('returns the arithmetic mean when rows match', () async {
      final adapter = await _adapter();
      final average = await adapter.avg(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.avg,
          column: 'age',
        ),
      );
      expect(average, 32.5);
    });
  });

  group('min', () {
    test('returns null for an empty result set', () async {
      final adapter = await _adapter(seed: false);
      final value = await adapter.min(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.min,
          column: 'age',
        ),
      );
      expect(value, isNull);
    });

    test('returns the smallest value when rows match', () async {
      final adapter = await _adapter();
      final value = await adapter.min(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.min,
          column: 'age',
        ),
      );
      expect(value, 25);
    });
  });

  group('max', () {
    test('returns null for an empty result set', () async {
      final adapter = await _adapter(seed: false);
      final value = await adapter.max(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.max,
          column: 'age',
        ),
      );
      expect(value, isNull);
    });

    test('returns the largest value when rows match', () async {
      final adapter = await _adapter();
      final value = await adapter.max(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.max,
          column: 'age',
        ),
      );
      expect(value, 40);
    });
  });
}
