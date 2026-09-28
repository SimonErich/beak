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
  Map<String, Object?> overTheWire(Map<String, Object?> json) =>
      switch (jsonDecode(jsonEncode(json))) {
        final Map<String, Object?> decoded => decoded,
        final Object? other => fail('Expected a JSON object, got $other.'),
      };
  BeakSummaryResult pinnedResult() => BeakSummaryResult(
    rows: [
      BeakSummaryRow(
        group: const BeakStringValue('paid'),
        values: {'count': 3, 'gross': 1250.5},
      ),
      BeakSummaryRow(
        group: const BeakNullValue(),
        values: {'count': 0, 'gross': 0},
      ),
    ],
    truncated: true,
  );
  test('typed definition and result survive JSON transport', () {
    final original = spec();
    final decoded = BeakSummarySpec.fromJson(overTheWire(original.toJson()));
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
  test('the wire format is pinned byte for byte', () {
    const specWire =
        '{"table":"orders","groupBy":"status","measures":[{"key":"count",'
        '"column":null,"filter":{"type":"field","column":"status",'
        '"operator":"eq","value":"paid"}},{"key":"gross","column":"cents"}],'
        '"filter":null,"search":null,"limit":100,"withTrashed":false}';
    const resultWire =
        '{"rows":[{"group":"paid","values":{"count":3,"gross":1250.5}},'
        '{"group":null,"values":{"count":0,"gross":0}}],"truncated":true}';
    expect(jsonEncode(spec().toJson()), specWire);
    expect(jsonEncode(pinnedResult().toJson()), resultWire);
    expect(
      jsonEncode(
        BeakSummarySpec.fromJson(overTheWire(spec().toJson())).toJson(),
      ),
      specWire,
    );
    expect(
      jsonEncode(
        BeakSummaryResult.fromJson(
          overTheWire(pinnedResult().toJson()),
        ).toJson(),
      ),
      resultWire,
    );
  });
  test('absent and null optional keys decode to their defaults', () {
    final measure = BeakSummaryMeasure.fromJson({'key': 'count'});
    expect(measure.columnKey, isNull);
    expect(measure.filter, isNull);
    for (final optional in <Map<String, Object?>>[
      {},
      {'groupBy': null, 'limit': null},
    ]) {
      final decoded = BeakSummarySpec.fromJson({
        'table': 'orders',
        'measures': [
          {'key': 'count'},
        ],
        ...optional,
      });
      expect(decoded.groupByKey, isNull, reason: '$optional');
      expect(decoded.limit, 100, reason: '$optional');
    }
    final grouped = BeakSummarySpec.fromJson({
      'table': 'orders',
      'groupBy': 'status',
      'limit': 7,
      'measures': [
        {'key': 'gross', 'column': 'cents'},
      ],
    });
    expect(grouped.groupByKey, 'status');
    expect(grouped.limit, 7);
    expect(grouped.measures.single.columnKey, 'cents');
  });
  test('integer and fractional values decode unchanged', () {
    final row = BeakSummaryRow.fromJson({
      'group': 'paid',
      'values': {'count': 3, 'gross': 1250.5},
    });
    expect(row.group, const BeakStringValue('paid'));
    expect(row.values, {'count': 3, 'gross': 1250.5});
    expect(row.values['count'], isA<int>());
    expect(row.values['gross'], isA<double>());
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
