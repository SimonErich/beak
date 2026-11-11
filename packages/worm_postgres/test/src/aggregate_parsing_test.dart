import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

void main() {
  const descriptor = AggregateDescriptor(
    table: 'items',
    function: AggregateFunction.sum,
    column: 'quantity',
    groupBy: 'productId',
  );

  test(
    'grouped aggregates retain numbers, numeric strings and null groups',
    () {
      expect(
        parseGroupedAggregateRows([
          {'group': 'a', 'value': 2},
          {'group': 'b', 'value': '6'},
          {'group': null, 'value': '3.5'},
          {'group': 'empty', 'value': null},
        ], descriptor),
        {'a': 2, 'b': 6, null: 3.5},
      );
    },
  );

  test('malformed grouped values raise a query error', () {
    for (final value in <Object>['invalid', true]) {
      expect(
        () => parseGroupedAggregateRows([
          {'group': 'a', 'value': value},
        ], descriptor),
        throwsA(isA<QueryException>()),
      );
    }
  });

  test('scalar sums use the same nullable numeric parsing', () {
    expect(parseAggregateSum({'sum': '6'}, descriptor), 6);
    expect(parseAggregateSum({'sum': null}, descriptor), isNull);
    expect(
      () => parseAggregateSum({'sum': 'invalid'}, descriptor),
      throwsA(isA<QueryException>()),
    );
  });
}
