import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const status = BeakStringColumn(key: 'status', label: 'Status');
  const lastActive = BeakDateTimeColumn(
    key: 'last_active',
    label: 'Last active',
  );

  final cutoff = DateTime.utc(2026);

  BeakFilter representativeTree() => BeakAndFilter([
    BeakFieldFilter(
      column: status,
      operator: BeakOperator.eq,
      value: BeakValue.of('active'),
    ),
    BeakOrFilter([
      BeakFieldFilter(
        column: lastActive,
        operator: BeakOperator.lt,
        value: BeakValue.of(cutoff),
      ),
      const BeakFieldFilter.forKey('deleted_at', BeakOperator.isNull),
    ]),
  ]);

  const representativeJson = <String, Object?>{
    'type': 'and',
    'filters': [
      {
        'type': 'field',
        'column': 'status',
        'operator': 'eq',
        'value': 'active',
      },
      {
        'type': 'or',
        'filters': [
          {
            'type': 'field',
            'column': 'last_active',
            'operator': 'lt',
            'value': {'type': 'dateTime', 'value': '2026-01-01T00:00:00.000Z'},
          },
          {
            'type': 'field',
            'column': 'deleted_at',
            'operator': 'isNull',
            'value': null,
          },
        ],
      },
    ],
  };

  group('BeakFieldFilter', () {
    test('reads its column key from the typed column constant', () {
      final filter = BeakFieldFilter(
        column: status,
        operator: BeakOperator.eq,
        value: BeakValue.of('active'),
      );
      expect(filter.columnKey, 'status');
      expect(filter.operator, BeakOperator.eq);
      expect(filter.value, const BeakStringValue('active'));
    });

    test('defaults its value to BeakNullValue for operand-less operators', () {
      expect(
        const BeakFieldFilter(
          column: status,
          operator: BeakOperator.isNotNull,
        ).value,
        const BeakNullValue(),
      );
      expect(
        const BeakFieldFilter.forKey('status', BeakOperator.isNull).value,
        const BeakNullValue(),
      );
    });
  });

  group('toJson', () {
    test('pins the exact JSON map of a representative nested tree', () {
      expect(representativeTree().toJson(), representativeJson);
    });

    test('a date range of local days travels as UTC instants and decodes '
        'to the same range', () {
      final filter = BeakFieldFilter.forKey(
        'created_at',
        BeakOperator.between,
        BeakListValue([
          BeakDateTimeValue(DateTime(2026, 3, 1)),
          BeakDateTimeValue(DateTime(2026, 4, 1)),
        ]),
      );
      final wire = filter.toJson();
      expect(wire['value'], [
        {
          'type': 'dateTime',
          'value': DateTime(2026, 3, 1).toUtc().toIso8601String(),
        },
        {
          'type': 'dateTime',
          'value': DateTime(2026, 4, 1).toUtc().toIso8601String(),
        },
      ]);
      expect(BeakFilter.fromJson(wire), filter);
    });
  });

  group('fromJson', () {
    test('decodes a nested tree back to a deep-equal filter', () {
      expect(BeakFilter.fromJson(representativeJson), representativeTree());
    });

    test('round-trips a representative tree losslessly', () {
      final tree = representativeTree();
      expect(BeakFilter.fromJson(tree.toJson()), tree);
    });

    test('rejects JSON without a type tag', () {
      expect(
        () => BeakFilter.fromJson(const {}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects JSON with an unknown type tag', () {
      expect(
        () => BeakFilter.fromJson(const {'type': 'xor', 'filters': []}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects field nodes missing a key', () {
      expect(
        () => BeakFilter.fromJson(const {'type': 'field', 'operator': 'eq'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakFilter.fromJson(const {'type': 'field', 'column': 'a'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'field',
          'column': 'a',
          'operator': 'eq',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects field nodes with wrongly typed keys', () {
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'field',
          'column': 5,
          'operator': 'eq',
          'value': null,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'field',
          'column': 'a',
          'operator': 17,
          'value': null,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects field nodes with an unknown operator name', () {
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'field',
          'column': 'a',
          'operator': 'noSuchOp',
          'value': null,
        }),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('noSuchOp'),
          ),
        ),
      );
    });

    test('propagates malformed nested values', () {
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'field',
          'column': 'a',
          'operator': 'eq',
          'value': {'type': 'bogus'},
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects and/or nodes whose filters are not a list of objects', () {
      expect(
        () => BeakFilter.fromJson(const {'type': 'and'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakFilter.fromJson(const {'type': 'and', 'filters': 'nope'}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakFilter.fromJson(const {
          'type': 'or',
          'filters': [1],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal trees compare equal and hash consistently', () {
      expect(representativeTree(), representativeTree());
      expect(representativeTree().hashCode, representativeTree().hashCode);
      expect(
        BeakFieldFilter.forKey(runtimeValue('a'), BeakOperator.eq),
        const BeakFieldFilter.forKey('a', BeakOperator.eq),
      );
      expect(
        BeakFieldFilter.forKey(runtimeValue('a'), BeakOperator.eq).hashCode,
        const BeakFieldFilter.forKey('a', BeakOperator.eq).hashCode,
      );
    });

    test('field filters differ by column, operator, or value', () {
      const base = BeakFieldFilter.forKey(
        'a',
        BeakOperator.eq,
        BeakIntValue(1),
      );
      expect(
        base,
        isNot(
          const BeakFieldFilter.forKey('b', BeakOperator.eq, BeakIntValue(1)),
        ),
      );
      expect(
        base,
        isNot(
          const BeakFieldFilter.forKey('a', BeakOperator.neq, BeakIntValue(1)),
        ),
      );
      expect(
        base,
        isNot(
          const BeakFieldFilter.forKey('a', BeakOperator.eq, BeakIntValue(2)),
        ),
      );
    });

    test('group filters compare children element-wise', () {
      const one = BeakFieldFilter.forKey('a', BeakOperator.isNull);
      const two = BeakFieldFilter.forKey('b', BeakOperator.isNotNull);
      expect(const BeakAndFilter([one, two]), const BeakAndFilter([one, two]));
      expect(
        const BeakAndFilter([one, two]),
        isNot(const BeakAndFilter([two, one])),
      );
      expect(
        const BeakAndFilter([one]),
        isNot(const BeakAndFilter([one, two])),
      );
      expect(const BeakOrFilter([one]), const BeakOrFilter([one]));
      expect(const BeakOrFilter([one]), isNot(const BeakOrFilter([two])));
    });

    test('a conjunction never equals a disjunction', () {
      const child = BeakFieldFilter.forKey('a', BeakOperator.isNull);
      expect(const BeakAndFilter([child]), isNot(const BeakOrFilter([child])));
      expect(
        const BeakAndFilter([child]).hashCode,
        isNot(const BeakOrFilter([child]).hashCode),
      );
    });
  });

  group('toString', () {
    test('names the node and its parts', () {
      expect(
        const BeakFieldFilter.forKey(
          'a',
          BeakOperator.eq,
          BeakIntValue(1),
        ).toString(),
        'BeakFieldFilter(a eq BeakIntValue(1))',
      );
      expect(const BeakAndFilter([]).toString(), 'BeakAndFilter([])');
      expect(const BeakOrFilter([]).toString(), 'BeakOrFilter([])');
    });
  });

  group('allOf', () {
    test('collapses lists into null, the single filter, or an AND', () {
      const single = BeakFieldFilter.forKey('a', BeakOperator.eq);
      const other = BeakFieldFilter.forKey('b', BeakOperator.eq);
      expect(BeakFilter.allOf(const []), isNull);
      expect(BeakFilter.allOf(const [single]), same(single));
      expect(
        BeakFilter.allOf(const [single, other]),
        const BeakAndFilter([single, other]),
      );
    });
  });
}
