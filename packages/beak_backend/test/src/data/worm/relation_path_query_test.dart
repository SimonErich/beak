import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

void main() {
  late WormDataSource source;

  setUp(() async {
    final adapter = await createTestDatabase();
    source = WormDataSource(createTestRegistry(), adapter: adapter);
    await source.create(
      'categories',
      BeakRecord.fromRow({'id': 1, 'name': 'Coffee'}),
    );
    await source.create(
      'categories',
      BeakRecord.fromRow({'id': 2, 'name': 'Tea'}),
    );
    await source.create(
      'products',
      BeakRecord.fromRow({'id': 1, 'name': 'Beans', 'category_id': 1}),
    );
    await source.create(
      'products',
      BeakRecord.fromRow({'id': 2, 'name': 'Leaves', 'category_id': 2}),
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
    await source.create(
      'reviews',
      BeakRecord.fromRow({
        'id': 3,
        'product_id': 2,
        'rating': 5,
        'body': 'Visible',
      }),
    );
    await source.create(
      'tags',
      BeakRecord.fromRow({'id': 1, 'name': 'Organic'}),
    );
    await source.attach('products', 1, 'tags', [1]);
  });
  tearDown(Worm.reset);

  test(
    'search traverses to-one and to-many relationships without duplicate owners',
    () async {
      final byCategory = await source.query(
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('coffee', ['category.name']),
        ),
      );
      expect(byCategory.items.map((record) => record['name']?.raw), ['Beans']);
      final byReview = await source.query(
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('i', ['reviews.body']),
          pagination: BeakPagination(perPage: 1),
        ),
      );
      expect(byReview.total, 2);
      expect(byReview.items, hasLength(1));
      final byTag = await source.query(
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('organic', ['tags.name']),
        ),
      );
      expect(byTag.items.single['name']?.raw, 'Beans');
    },
  );

  test(
    'numeric search uses typed equality across root and related paths',
    () async {
      final byId = await source.query(
        const BeakQuerySpec(table: 'products', search: BeakSearch('2', ['id'])),
      );
      expect(byId.items.single['name']?.raw, 'Leaves');
      final byReview = await source.query(
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('1', ['reviews.rating']),
        ),
      );
      expect(byReview.items.single['name']?.raw, 'Beans');
      final noMatch = await source.query(
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('invalid integer', ['id']),
        ),
      );
      expect(noMatch.total, 0);
    },
  );

  test('a grouped relation predicate must match the same child', () async {
    final result = await source.query(
      const BeakQuerySpec(
        table: 'products',
        filter: BeakRelationFilter(
          'reviews',
          BeakAndFilter([
            BeakFieldFilter.forKey('rating', BeakOperator.eq, BeakIntValue(5)),
            BeakFieldFilter.forKey(
              'body',
              BeakOperator.eq,
              BeakStringValue('Visible'),
            ),
          ]),
        ),
      ),
    );
    expect(result.items.map((record) => record['name']?.raw), ['Leaves']);
  });

  test('unknown relationship paths fail before querying', () {
    expect(
      () => source.query(
        const BeakQuerySpec(
          table: 'products',
          filter: BeakFieldFilter.forKey(
            'missing.name',
            BeakOperator.eq,
            BeakStringValue('x'),
          ),
        ),
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('related scopes constrain the same child used by a search', () async {
    final handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: createTestRegistry(),
            dataSource: source,
            policy: const _VisibleReviews(),
          ),
        );
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/products/query'),
        body: jsonEncode(
          const BeakQuerySpec(
            table: 'products',
            search: BeakSearch('hidden', ['reviews.body']),
          ).toJson(),
        ),
      ),
    );
    expect(response.statusCode, 200);
    final Object? body = jsonDecode(await response.readAsString());
    expect(body, containsPair('total', 0));
  });
}

final class _VisibleReviews extends BeakAllowAllPolicy
    implements BeakRowPolicy {
  const _VisibleReviews();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      table == 'reviews'
      ? const BeakFieldFilter.forKey(
          'body',
          BeakOperator.eq,
          BeakStringValue('Visible'),
        )
      : null;
}
