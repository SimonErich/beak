import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const relation = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    searchColumnKeys: ['name', 'slug'],
    foreignKey: 'category_id',
  );

  test('stores its configuration', () {
    expect(relation.key, 'category');
    expect(relation.label, 'Category');
    expect(relation.relatedTable, 'categories');
    expect(relation.displayColumnKey, 'name');
    expect(relation.searchColumnKeys, const ['name', 'slug']);
    expect(relation.foreignKey, 'category_id');
  });

  test('searchColumnKeys defaults to empty', () {
    const bare = BeakBelongsTo(
      key: 'category',
      label: 'Category',
      relatedTable: 'categories',
      displayColumnKey: 'name',
      foreignKey: 'category_id',
    );
    expect(bare.searchColumnKeys, isEmpty);
  });

  test('resolves to one related record', () {
    expect(relation.cardinality, BeakRelationCardinality.one);
  });

  test('renders as a relation link in every context', () {
    for (final context in BeakContext.values) {
      expect(
        relation.intentFor(context),
        BeakRenderIntent.relationLink,
        reason: '$context',
      );
    }
  });
}
