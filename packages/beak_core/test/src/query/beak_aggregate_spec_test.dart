import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const priceColumn = BeakDecimalColumn(key: 'price', label: 'Price');
  const activeColumn = BeakBoolColumn(key: 'active', label: 'Active');

  group('typed builders', () {
    test('count carries no column', () {
      const spec = BeakAggregateSpec.count(table: 'products');
      expect(spec.table, 'products');
      expect(spec.function, BeakAggregateFunction.count);
      expect(spec.columnKey, isNull);
      expect(spec.filter, isNull);
      expect(spec.withTrashed, isFalse);
    });

    test('sum reads the column key from the column constant', () {
      const spec = BeakAggregateSpec.sum(
        table: 'products',
        column: priceColumn,
      );
      expect(spec.function, BeakAggregateFunction.sum);
      expect(spec.columnKey, 'price');
    });

    test('avg reads the column key and keeps the filter', () {
      const spec = BeakAggregateSpec.avg(
        table: 'products',
        column: priceColumn,
        filter: BeakFieldFilter(
          column: activeColumn,
          operator: BeakOperator.eq,
          value: BeakBoolValue(true),
        ),
        withTrashed: true,
      );
      expect(spec.function, BeakAggregateFunction.avg);
      expect(spec.columnKey, 'price');
      expect(spec.filter, isNotNull);
      expect(spec.withTrashed, isTrue);
    });
  });

  group('forKey', () {
    test('builds a valid spec from raw keys', () {
      final spec = BeakAggregateSpec.forKey(
        table: 'products',
        function: BeakAggregateFunction.sum,
        columnKey: 'price',
      );
      expect(spec.columnKey, 'price');
    });

    test('rejects sum and avg without a column key', () {
      for (final function in [
        BeakAggregateFunction.sum,
        BeakAggregateFunction.avg,
      ]) {
        expect(
          () => BeakAggregateSpec.forKey(table: 'products', function: function),
          throwsA(isA<BeakConfigurationException>()),
          reason: function.name,
        );
      }
    });

    test('rejects count with a column key', () {
      expect(
        () => BeakAggregateSpec.forKey(
          table: 'products',
          function: BeakAggregateFunction.count,
          columnKey: 'price',
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('JSON round-trip', () {
    test('serializes every key, writing null for absent parts', () {
      const spec = BeakAggregateSpec.count(table: 'products');
      expect(spec.toJson(), {
        'table': 'products',
        'function': 'count',
        'column': null,
        'filter': null,
        'withTrashed': false,
      });
    });

    test('decode(encode(spec)) is deep-equal after a JSON wire trip', () {
      const spec = BeakAggregateSpec.avg(
        table: 'products',
        column: priceColumn,
        filter: BeakFieldFilter(
          column: activeColumn,
          operator: BeakOperator.eq,
          value: BeakBoolValue(true),
        ),
        withTrashed: true,
      );
      final decoded = switch (jsonDecode(jsonEncode(spec.toJson()))) {
        final Map<String, Object?> map => BeakAggregateSpec.fromJson(map),
        final Object? other => fail('expected a JSON object, got $other'),
      };
      expect(decoded, spec);
      expect(decoded.hashCode, spec.hashCode);
    });

    test('decode(encode(count)) preserves the column-less shape', () {
      const spec = BeakAggregateSpec.count(table: 'products');
      expect(BeakAggregateSpec.fromJson(spec.toJson()), spec);
    });

    test('fromJson rejects an unknown function name', () {
      expect(
        () => BeakAggregateSpec.fromJson({
          'table': 'products',
          'function': 'median',
          'column': null,
          'filter': null,
          'withTrashed': false,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects an empty table', () {
      expect(
        () => BeakAggregateSpec.fromJson({
          'table': '',
          'function': 'count',
          'column': null,
          'filter': null,
          'withTrashed': false,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a non-map filter', () {
      expect(
        () => BeakAggregateSpec.fromJson({
          'table': 'products',
          'function': 'count',
          'column': null,
          'filter': 42,
          'withTrashed': false,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson needs only the table and the function', () {
      final spec = BeakAggregateSpec.fromJson(<String, Object?>{
        'table': 'products',
        'function': 'count',
      });

      expect(spec.table, 'products');
      expect(spec.function, BeakAggregateFunction.count);
      expect(spec.columnKey, isNull);
      expect(spec.filter, isNull);
      expect(spec.withTrashed, isFalse);
    });

    test('fromJson rejects a non-boolean withTrashed', () {
      expect(
        () => BeakAggregateSpec.fromJson({
          'table': 'products',
          'function': 'count',
          'withTrashed': 'yes',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a non-string column', () {
      expect(
        () => BeakAggregateSpec.fromJson({
          'table': 'products',
          'function': 'sum',
          'column': 42,
          'filter': null,
          'withTrashed': false,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('specs with equal parts are equal', () {
      expect(
        runtimeValue(const BeakAggregateSpec.count(table: 'products')),
        const BeakAggregateSpec.count(table: 'products'),
      );
      expect(
        const BeakAggregateSpec.count(table: 'products').hashCode,
        const BeakAggregateSpec.count(table: 'products').hashCode,
      );
    });

    test('any differing part breaks equality', () {
      final base = runtimeValue(
        const BeakAggregateSpec.count(table: 'products'),
      );
      expect(base, isNot(const BeakAggregateSpec.count(table: 'users')));
      expect(
        base,
        isNot(
          const BeakAggregateSpec.sum(table: 'products', column: priceColumn),
        ),
      );
      expect(
        const BeakAggregateSpec.sum(table: 'products', column: priceColumn),
        isNot(
          const BeakAggregateSpec.avg(table: 'products', column: priceColumn),
        ),
      );
      expect(
        const BeakAggregateSpec.sum(table: 'products', column: priceColumn),
        isNot(
          const BeakAggregateSpec.sum(table: 'products', column: activeColumn),
        ),
      );
      expect(
        base,
        isNot(
          const BeakAggregateSpec.count(table: 'products', withTrashed: true),
        ),
      );
      expect(
        base,
        isNot(
          const BeakAggregateSpec.count(
            table: 'products',
            filter: BeakFieldFilter(
              column: activeColumn,
              operator: BeakOperator.eq,
              value: BeakBoolValue(true),
            ),
          ),
        ),
      );
    });
  });

  test('toString names the function and table', () {
    final rendered = const BeakAggregateSpec.count(
      table: 'products',
    ).toString();
    expect(rendered, contains('count'));
    expect(rendered, contains('products'));
  });
}
