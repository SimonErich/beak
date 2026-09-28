import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/test_models.dart';

final class _Policy extends BeakAllowAllPolicy
    implements BeakFieldPolicy, BeakRowPolicy {
  const _Policy();
  @override
  bool canReadField(BeakPrincipal? principal, String table, String key) =>
      key != 'price' && key != 'body';
  @override
  bool canWriteField(BeakPrincipal? principal, String table, String key) =>
      key != 'price' && key != 'tags';
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) =>
      table == 'products'
      ? const BeakFieldFilter.forKey(
          'price',
          BeakOperator.gt,
          BeakDoubleValue(0),
        )
      : null;
}

void main() {
  late WormDataSource source;
  late Handler handler;
  Handler serve(BeakPolicy policy) => const Pipeline()
      .addMiddleware(beakErrorMappingMiddleware())
      .addHandler(
        beakApiRouter(
          registry: createTestRegistry(),
          dataSource: source,
          policy: policy,
        ),
      );
  setUp(() async {
    source = WormDataSource(
      createTestRegistry(),
      adapter: await createTestDatabase(),
    );
    await source.create(
      'products',
      BeakRecord.fromRow({'id': 1, 'name': 'Beans', 'price': 9.5}),
    );
    await source.create(
      'reviews',
      BeakRecord.fromRow({
        'id': 2,
        'product_id': 1,
        'rating': 5,
        'body': 'Secret review',
      }),
    );
    handler = serve(const _Policy());
  });
  tearDown(Worm.reset);
  Future<Response> request(String method, String path, [Object? body]) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost/api$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  test(
    'summary measure predicates cannot infer protected direct or related fields',
    () async {
      for (final key in ['price', 'reviews.body']) {
        final response = await request(
          'POST',
          '/products/summary',
          BeakSummarySpec(
            table: 'products',
            measures: [
              BeakSummaryMeasure.count(
                'secretCount',
                filter: BeakFieldFilter.forKey(
                  key,
                  BeakOperator.isNotNull,
                  const BeakNullValue(),
                ),
              ),
            ],
          ).toJson(),
        );
        expect(response.statusCode, 401, reason: key);
      }
      final allowed = await request(
        'POST',
        '/products/summary',
        BeakSummarySpec(
          table: 'products',
          measures: [
            const BeakSummaryMeasure.count(
              'named',
              filter: BeakFieldFilter.forKey(
                'name',
                BeakOperator.eq,
                BeakStringValue('Beans'),
              ),
            ),
          ],
        ).toJson(),
      );
      expect(allowed.statusCode, 200);
      expect(await allowed.readAsString(), contains('"named":1'));
    },
  );

  test('query, identity and batch redact fields and loaded children', () async {
    final query = await request(
      'POST',
      '/products/query',
      const BeakQuerySpec(
        table: 'products',
        relationLoads: [BeakRelationLoad('reviews')],
      ).toJson(),
    );
    expect(query.statusCode, 200);
    final body = await query.readAsString();
    expect(body, contains('Beans'));
    expect(body, contains('rating'));
    expect(body, isNot(contains('price')));
    expect(body, isNot(contains('Secret review')));
    for (final response in [
      await request('GET', '/products/1'),
      await request('POST', '/products/batch', {
        'ids': [1],
      }),
    ]) {
      expect(response.statusCode, 200);
      expect(await response.readAsString(), isNot(contains('price')));
    }
  });

  test(
    'filter, sorting, search and aggregates cannot infer denied fields',
    () async {
      final specs = [
        const BeakQuerySpec(
          table: 'products',
          filter: BeakFieldFilter.forKey(
            'price',
            BeakOperator.gt,
            BeakDoubleValue(1),
          ),
        ),
        const BeakQuerySpec(table: 'products', sorts: [BeakSort('price')]),
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('Secret', ['reviews.body']),
        ),
      ];
      for (final spec in specs) {
        expect(
          (await request('POST', '/products/query', spec.toJson())).statusCode,
          401,
        );
      }
      expect(
        (await request(
          'POST',
          '/products/aggregate',
          const BeakAggregateSpec.sum(
            table: 'products',
            column: ProductColumns.price,
          ).toJson(),
        )).statusCode,
        401,
      );
    },
  );

  test('summaries cannot infer hidden grouping or measure fields', () async {
    for (final spec in [
      BeakSummarySpec(
        table: 'products',
        groupBy: ProductColumns.price,
        measures: const [BeakSummaryMeasure.count('count')],
      ),
      BeakSummarySpec(
        table: 'products',
        measures: [BeakSummaryMeasure.sum('sum', column: ProductColumns.price)],
      ),
    ]) {
      expect(
        (await request('POST', '/products/summary', spec.toJson())).statusCode,
        401,
      );
    }
  });

  test(
    'write, preflight and relationship changes reject protected inputs',
    () async {
      expect(
        (await request('PATCH', '/products/1', {'price': 1})).statusCode,
        401,
      );
      expect(
        (await request('POST', '/products', {
          'name': 'Bypass',
          'price': 1,
        })).statusCode,
        401,
      );
      expect(
        (await request(
          'POST',
          '/products/validate',
          BeakValidationRequest(
            table: 'products',
            recordId: 1,
            record: BeakRecord.fromRow({'price': 1}),
          ).toJson(),
        )).statusCode,
        401,
      );
      for (final action in ['attach', 'detach']) {
        expect(
          (await request('POST', '/products/1/relations/tags/$action', {
            'ids': [1],
          })).statusCode,
          401,
        );
      }
      final allowed = await request('PATCH', '/products/1', {
        'name': 'Updated',
      });
      expect(allowed.statusCode, 200);
      expect(await allowed.readAsString(), isNot(contains('price')));
      expect((await source.getOne('products', 1))!['price']?.raw, 9.5);
    },
  );

  test('CSV export shares field visibility', () async {
    final csv = await request(
      'POST',
      '/products/export',
      const BeakQuerySpec(table: 'products').toJson(),
    );
    expect(csv.statusCode, 200);
    final body = await csv.readAsString();
    expect(body, contains('Beans'));
    expect(body, isNot(contains('Price')));
    expect(body, isNot(contains('9.5')));
  });

  test(
    'capabilities describe access without leaking protected values',
    () async {
      final response = await request('GET', '/products/capabilities?id=1');
      expect(response.statusCode, 200);
      final decoded = jsonDecode(await response.readAsString());
      if (decoded is! Map<String, Object?>) {
        fail('Expected capabilities object');
      }
      final access = BeakAccessCapabilities.fromJson(decoded);
      expect(access.canRead('name'), isTrue);
      expect(access.canRead('price'), isFalse);
      expect(access.canWrite('price'), isFalse);
      expect(access.canWrite('tags'), isFalse);
      expect(
        (await request('GET', '/products/capabilities?id=999')).statusCode,
        404,
      );
    },
  );
}
