import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const group = BeakStringColumn(key: 'status', label: 'Status');
  const amount = BeakIntColumn(key: 'cents', label: 'Amount');
  BeakSummarySpec spec() => BeakSummarySpec(
    table: 'orders',
    groupBy: group,
    measures: [
      const BeakSummaryMeasure.count(
        'count',
        filter: BeakFieldFilter.forKey(
          'status',
          BeakOperator.eq,
          BeakStringValue('paid'),
        ),
      ),
      BeakSummaryMeasure.sum('gross', column: amount),
    ],
  );
  test('typed definition and result survive JSON transport', () {
    final original = spec();
    final decoded = BeakSummarySpec.fromJson(
      (jsonDecode(jsonEncode(original.toJson())) as Map)
          .cast<String, Object?>(),
    );
    expect(decoded.toJson(), original.toJson());
    final result = BeakSummaryResult(
      rows: [
        BeakSummaryRow(
          group: const BeakNullValue(),
          values: {'count': 0, 'gross': 0},
        ),
      ],
    );
    expect(
      BeakSummaryResult.fromJson(result.toJson()).toJson(),
      result.toJson(),
    );
    expect(() => decoded.measures.clear(), throwsUnsupportedError);
    expect(() => result.rows.clear(), throwsUnsupportedError);
    expect(() => result.rows.first.values.clear(), throwsUnsupportedError);
  });
  test('population replacement retains measures and rejects another table', () {
    final original = spec();
    const query = BeakQuerySpec(
      table: 'orders',
      filter: BeakFieldFilter(
        column: group,
        operator: BeakOperator.eq,
        value: BeakStringValue('paid'),
      ),
      withTrashed: true,
    );
    final changed = original.withQuery(query);
    expect(changed.filter, query.filter);
    expect(changed.withTrashed, isTrue);
    expect(changed.groupByKey, 'status');
    expect(
      () => original.withQuery(const BeakQuerySpec(table: 'users')),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
  test('malformed and unbounded requests fail at the wire boundary', () {
    final base = spec().toJson();
    for (final patch in <Map<String, Object?>>[
      {'table': ''},
      {'groupBy': ''},
      {'groupBy': 1},
      {'limit': 0},
      {'limit': 501},
      {'limit': 1.2},
      {
        'measures': [
          {'key': 'x', 'filter': 'invalid'},
        ],
      },
      {'measures': []},
      {
        'measures': List.filled(9, {'key': 'x'}),
      },
      {
        'measures': [
          {'key': ''},
        ],
      },
      {
        'measures': [
          {'key': 'x' * 81},
        ],
      },
      {
        'measures': [
          {'key': 'x', 'column': ''},
        ],
      },
      {
        'measures': [
          {'key': 'x', 'column': 42},
        ],
      },
      {
        'measures': [
          {'key': 'x'},
          {'key': 'x'},
        ],
      },
    ]) {
      expect(
        () => BeakSummarySpec.fromJson({...base, ...patch}),
        throwsA(isA<BeakConfigurationException>()),
        reason: '$patch',
      );
    }
    expect(
      () => BeakSummaryRow.fromJson({
        'group': null,
        'values': {'count': '3'},
      }),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakSummaryRow(
        group: const BeakNullValue(),
        values: {'sum': double.nan},
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}
