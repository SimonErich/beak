import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/test_models.dart';

Map<String, Object?> _jsonObject(Object? value) => switch (value) {
  final Map<String, Object?> object => object,
  _ => fail('Expected a JSON object.'),
};

final class _Policy extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _Policy({this.denyReviews = false});
  final bool denyReviews;
  @override
  bool canView(BeakPrincipal? principal, String table) =>
      !denyReviews || table != 'reviews';
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      switch (table) {
        'reviews' => const BeakFieldFilter.forKey(
          'body',
          BeakOperator.eq,
          BeakStringValue('Visible'),
        ),
        _ => null,
      };
}

void main() {
  late WormDataSource source;
  late Handler handler;
  setUp(() async {
    final adapter = await createTestDatabase();
    final registry = createTestRegistry();
    source = WormDataSource(registry, adapter: adapter);
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
    handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: source,
            policy: const _Policy(),
          ),
        );
  });
  tearDown(Worm.reset);

  Future<Response> post(String path, Object body) async => handler(
    Request('POST', Uri.parse('http://localhost$path'), body: jsonEncode(body)),
  );

  test(
    'aggregate and CSV export cannot match a hidden related child',
    () async {
      const filter = BeakFieldFilter.forKey(
        'reviews.rating',
        BeakOperator.eq,
        BeakIntValue(5),
      );
      final aggregate = await post(
        '/api/products/aggregate',
        const BeakAggregateSpec.count(
          table: 'products',
          filter: filter,
        ).toJson(),
      );
      expect(aggregate.statusCode, 200);
      expect(jsonDecode(await aggregate.readAsString()), {'value': 0});
      final export = await post(
        '/api/products/export',
        const BeakQuerySpec(table: 'products', filter: filter).toJson(),
      );
      expect(export.statusCode, 200);
      expect(await export.readAsString(), isNot(contains('Beans')));
    },
  );

  test('eager loads intersect their filter with the child scope', () async {
    const query = BeakQuerySpec(
      table: 'products',
      relationLoads: [BeakRelationLoad('reviews')],
    );
    final response = await post('/api/products/query', query.toJson());
    expect(response.statusCode, 200);
    final json = _jsonObject(jsonDecode(await response.readAsString()));
    final page = BeakPage.fromJson(
      json,
      (entry) => BeakRecord.fromJson(_jsonObject(entry)),
    );
    expect(
      page.items.single.relations['reviews']!.map((row) => row['body']?.raw),
      ['Visible'],
    );
  });

  test('nested eager loads authorize the target at every level', () async {
    const query = BeakQuerySpec(
      table: 'categories',
      relationLoads: [
        BeakRelationLoad('products', nested: [BeakRelationLoad('reviews')]),
      ],
    );
    final response = await post('/api/categories/query', query.toJson());
    expect(response.statusCode, 200);
    final json = _jsonObject(jsonDecode(await response.readAsString()));
    final page = BeakPage.fromJson(
      json,
      (entry) => BeakRecord.fromJson(_jsonObject(entry)),
    );
    final reviews =
        page.items.single.relations['products']!.single.relations['reviews']!;
    expect(reviews.map((row) => row['body']?.raw), ['Visible']);
  });

  test('unviewable targets cannot be searched or eagerly loaded', () async {
    handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: createTestRegistry(),
            dataSource: source,
            policy: const _Policy(denyReviews: true),
          ),
        );
    for (final spec in [
      const BeakQuerySpec(
        table: 'products',
        search: BeakSearch('Hidden', ['reviews.body']),
      ),
      const BeakQuerySpec(
        table: 'products',
        relationLoads: [BeakRelationLoad('reviews')],
      ),
    ]) {
      expect(
        (await post('/api/products/query', spec.toJson())).statusCode,
        401,
      );
    }
  });
}
