import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../support/test_models.dart';

final class _Visible extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _Visible();
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is ReviewModel ? ReviewModel.body.eq('Visible') : null;
}

void main() {
  test(
    'SQLite correlated counts and nested eager loads enforce child policies',
    () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      for (final schema in testSchema) {
        await adapter.executeSchema(
          SchemaDescriptor.createTable(
            table: schema.table,
            columns: [
              for (final column in schema.columns)
                SchemaColumn(
                  name: column.name,
                  type: column.type,
                  isPrimaryKey: column.isPrimaryKey,
                  nullable: !column.isPrimaryKey,
                ),
            ],
          ),
        );
      }
      final registry = createTestRegistry();
      final source = WormDataSource(registry, adapter: adapter);
      final authorizer = BeakQueryAuthorizer(
        registry: registry,
        policy: const _Visible(),
        principal: null,
      );
      await source.create(
        'categories',
        BeakRecord.fromRow({'id': 1, 'name': 'Coffee'}),
      );
      await source.create(
        'products',
        BeakRecord.fromRow({'id': 1, 'name': 'Beans', 'category_id': 1}),
      );
      await source.create(
        'reviews',
        BeakRecord.fromRow({
          'id': 1,
          'product_id': 1,
          'rating': 5,
          'body': 'Hidden',
        }),
      );
      await source.create(
        'reviews',
        BeakRecord.fromRow({
          'id': 2,
          'product_id': 1,
          'rating': 1,
          'body': 'Visible',
        }),
      );
      final hidden = await source.query(
        authorizer.authorizeQuery(
          const BeakQuerySpec(
            table: 'products',
            search: BeakSearch('Hidden', ['reviews.body']),
          ),
        ),
      );
      expect(hidden.total, 0);
      expect(hidden.items, isEmpty);
      final visible = await source.query(
        authorizer.authorizeQuery(
          const BeakQuerySpec(
            table: 'categories',
            search: BeakSearch('Visible', ['products.reviews.body']),
          ),
        ),
      );
      expect(visible.total, 1);
      expect(visible.items.single['name']?.raw, 'Coffee');
      final count = await source.aggregate(
        authorizer.authorizeAggregate(
          const BeakAggregateSpec.count(
            table: 'products',
            filter: BeakFieldFilter.forKey(
              'reviews.rating',
              BeakOperator.eq,
              BeakIntValue(5),
            ),
          ),
        ),
      );
      expect(count, 0);
      final nested = await source.query(
        authorizer.authorizeQuery(
          const BeakQuerySpec(
            table: 'categories',
            relationLoads: [
              BeakRelationLoad(
                'products',
                nested: [BeakRelationLoad('reviews')],
              ),
            ],
          ),
        ),
      );
      final reviews = nested
          .items
          .single
          .relations['products']!
          .single
          .relations['reviews']!;
      expect(reviews.map((row) => row['body']?.raw), ['Visible']);
    },
  );
}
