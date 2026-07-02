import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const relation = BeakHasMany(
    key: 'orders',
    label: 'Orders',
    relatedTable: 'orders',
    displayColumnKey: 'number',
    searchColumnKeys: ['number'],
    foreignKey: 'customer_id',
    onDelete: BeakOnDelete.setNull,
  );

  test('stores its configuration', () {
    expect(relation.key, 'orders');
    expect(relation.label, 'Orders');
    expect(relation.relatedTable, 'orders');
    expect(relation.displayColumnKey, 'number');
    expect(relation.searchColumnKeys, const ['number']);
    expect(relation.foreignKey, 'customer_id');
    expect(relation.onDelete, BeakOnDelete.setNull);
  });

  test('defaults: empty searchColumnKeys, restrict on delete', () {
    const bare = BeakHasMany(
      key: 'orders',
      label: 'Orders',
      relatedTable: 'orders',
      displayColumnKey: 'number',
      foreignKey: 'customer_id',
    );
    expect(bare.searchColumnKeys, isEmpty);
    expect(bare.onDelete, BeakOnDelete.restrict);
  });

  test('resolves to many related records', () {
    expect(relation.cardinality, BeakRelationCardinality.many);
  });

  test('renders as relation badges in every context', () {
    for (final context in BeakContext.values) {
      expect(
        relation.intentFor(context),
        BeakRenderIntent.relationBadges,
        reason: '$context',
      );
    }
  });
}
