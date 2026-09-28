import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('relationship filters have stable equality and diagnostic labels', () {
    const a = BeakRelationFilter(
      'items',
      BeakFieldFilter.forKey('id', BeakOperator.eq, BeakIntValue(3)),
    );
    const b = BeakRelationFilter(
      'items',
      BeakFieldFilter.forKey('id', BeakOperator.eq, BeakIntValue(3)),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('items'));
  });
  test('a related predicate survives transport with its grouping intact', () {
    const filter = BeakRelationFilter(
      'items',
      BeakAndFilter([
        BeakFieldFilter.forKey('quantity', BeakOperator.gte, BeakIntValue(2)),
        BeakFieldFilter.forKey(
          'product_id',
          BeakOperator.eq,
          BeakStringValue('p1'),
        ),
      ]),
    );
    expect(BeakFilter.fromJson(filter.toJson()), filter);
    expect(filter.toJson()['type'], 'relation');
    expect(filter.toJson()['relation'], 'items');
  });
}
