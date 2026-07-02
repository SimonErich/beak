import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const relation = BeakHasOne(
    key: 'profile',
    label: 'Profile',
    relatedTable: 'profiles',
    displayColumnKey: 'nickname',
    searchColumnKeys: ['nickname'],
    foreignKey: 'user_id',
  );

  test('stores its configuration', () {
    expect(relation.key, 'profile');
    expect(relation.label, 'Profile');
    expect(relation.relatedTable, 'profiles');
    expect(relation.displayColumnKey, 'nickname');
    expect(relation.searchColumnKeys, const ['nickname']);
    expect(relation.foreignKey, 'user_id');
  });

  test('searchColumnKeys defaults to empty', () {
    const bare = BeakHasOne(
      key: 'profile',
      label: 'Profile',
      relatedTable: 'profiles',
      displayColumnKey: 'nickname',
      foreignKey: 'user_id',
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
