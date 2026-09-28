import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;
  setUp(() async {
    adapter = await createTestDatabase();
    source = WormDataSource(createTestRegistry(), adapter: adapter);
    for (var i = 1; i <= 137; i++) {
      await source.create(
        'products',
        BeakRecord.fromRow({
          'id': i,
          'name': i.isEven ? 'Even' : 'Odd',
          'price': i,
          'active': i.isEven,
          'category_id': i % 3,
        }),
      );
    }
    await source.delete('products', 1);
  });
  tearDown(Worm.reset);
  BeakSummarySpec summary({
    BeakColumn? group,
    int limit = 100,
    bool withTrashed = false,
    BeakSearch? search,
  }) => BeakSummarySpec(
    table: 'products',
    groupBy: group,
    limit: limit,
    withTrashed: withTrashed,
    search: search,
    measures: [
      const BeakSummaryMeasure.count('count'),
      BeakSummaryMeasure.sum('value', column: ProductColumns.price),
    ],
  );
  test(
    'groups the whole dataset and preserves normal soft-delete scope',
    () async {
      final result = await source.summary(
        summary(group: ProductColumns.active),
      );
      expect(result.truncated, isFalse);
      expect(
        result.rows.map((r) => r.values['count']).reduce((a, b) => a! + b!),
        136,
      );
      expect(
        result.rows.map((r) => r.values['value']).reduce((a, b) => a! + b!),
        9452,
      );
      expect(result.rows.map((r) => r.group.raw), containsAll([false, true]));
      final total = await source.summary(summary(withTrashed: true));
      expect(total.rows.single.group, const BeakNullValue());
      expect(total.rows.single.values, {'count': 137, 'value': 9453});
    },
  );
  test('search uses the same population and overflow is explicit', () async {
    const search = BeakSearch('Even', ['name']);
    final result = await source.summary(
      summary(group: ProductColumns.categoryId, limit: 1, search: search),
    );
    expect(result.rows, hasLength(1));
    expect(result.truncated, isTrue);
    expect(result.rows.single.group.raw, 0);
    final total = await source.summary(summary(search: search));
    expect(total.rows.single.values['count'], 68);
  });
  test(
    'measure filters intersect the population and zero-fill absent groups',
    () async {
      final measures = [
        const BeakSummaryMeasure.count(
          'active',
          filter: BeakFieldFilter.forKey(
            'active',
            BeakOperator.eq,
            BeakBoolValue(true),
          ),
        ),
        BeakSummaryMeasure.sum(
          'inactiveTotal',
          column: ProductColumns.price,
          filter: const BeakFieldFilter.forKey(
            'active',
            BeakOperator.eq,
            BeakBoolValue(false),
          ),
        ),
      ];
      const population = BeakFieldFilter.forKey(
        'price',
        BeakOperator.lte,
        BeakIntValue(10),
      );
      final total = await source.summary(
        BeakSummarySpec(
          table: 'products',
          measures: measures,
          filter: population,
        ),
      );
      expect(total.rows.single.values, {'active': 5, 'inactiveTotal': 24});
      final groups = await source.summary(
        BeakSummarySpec(
          table: 'products',
          groupBy: ProductColumns.active,
          measures: measures,
          filter: population,
        ),
      );
      expect(groups.rows.first.values, {'active': 0, 'inactiveTotal': 24});
      expect(groups.rows.last.values, {'active': 5, 'inactiveTotal': 0});
    },
  );

  test(
    'invalid fields and cross-resource requests cannot fall back to a page',
    () async {
      await expectLater(
        source.summary(
          summary(
            group: const BeakStringColumn(key: 'missing', label: 'Missing'),
          ),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        source.summary(
          BeakSummarySpec(
            table: 'products',
            measures: [
              BeakSummaryMeasure.sum('sum', column: ProductColumns.name),
            ],
          ),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => BeakResourceService(
          const CategoryModel(),
          source,
        ).summary(summary()),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );
}
