import 'package:beak_backend/src/data/worm/query_translator.dart';
import 'package:beak_backend/src/data/worm/worm_record_model.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

/// Strips the always-applied paging window off [sql] so structural
/// assertions stay focused.
String _withoutPaging(String sql) {
  final int limitIndex = sql.indexOf(' LIMIT');
  return limitIndex < 0 ? sql : sql.substring(0, limitIndex);
}

void main() {
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late WormQueryTranslator translator;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createTestDatabase();
    registry = createTestRegistry();
    translator = WormQueryTranslator(registry);
  });

  tearDown(Worm.reset);

  QueryBuilder<WormRecordModel> build(BeakQuerySpec spec) =>
      translator.builderFor(spec, adapter);

  group('golden toSql', () {
    test('translates the rich spec to the pinned SQL', () {
      final spec = const BeakQuerySpec(table: 'products')
          .withFilter(
            const BeakFieldFilter(
              column: ProductColumns.price,
              operator: BeakOperator.gte,
              value: BeakDoubleValue(10.0),
            ),
          )
          .withFilter(
            const BeakFieldFilter(
              column: ProductColumns.active,
              operator: BeakOperator.eq,
              value: BeakBoolValue(true),
            ),
          )
          .orderBy(ProductModel.price, descending: true)
          .searching('laser', [ProductModel.name])
          .paginate(page: 2, perPage: 5);

      expect(
        build(spec).toSql(),
        'SELECT id, name, price, active, created_at, category_id FROM products WHERE (price >= 10.0 AND active = TRUE) '
        "AND (name ILIKE '%laser%') AND deleted_at IS NULL "
        'ORDER BY price DESC LIMIT 5 OFFSET 5',
      );
    });
  });

  group('operator mapping', () {
    /// Builds the WHERE fragment produced for a single field filter, with
    /// the soft-delete scope and the always-applied paging window stripped
    /// for focus.
    String whereFor(BeakFieldFilter filter) {
      final sql = build(
        BeakQuerySpec(table: 'products', filter: filter, withTrashed: true),
      ).toSql();
      const marker = ' WHERE ';
      final start = sql.indexOf(marker) + marker.length;
      final end = sql.indexOf(' LIMIT');
      return sql.substring(start, end < 0 ? sql.length : end);
    }

    BeakFieldFilter priceFilter(BeakOperator operator, BeakValue value) =>
        BeakFieldFilter(
          column: ProductColumns.price,
          operator: operator,
          value: value,
        );

    BeakFieldFilter nameFilter(BeakOperator operator, BeakValue value) =>
        BeakFieldFilter(
          column: ProductColumns.name,
          operator: operator,
          value: value,
        );

    test('every BeakOperator translates to its worm counterpart', () {
      final cases = <BeakOperator, (BeakFieldFilter, String)>{
        BeakOperator.eq: (
          priceFilter(BeakOperator.eq, const BeakDoubleValue(5.0)),
          'price = 5.0',
        ),
        BeakOperator.neq: (
          priceFilter(BeakOperator.neq, const BeakDoubleValue(5.0)),
          'price != 5.0',
        ),
        BeakOperator.gt: (
          priceFilter(BeakOperator.gt, const BeakDoubleValue(5.0)),
          'price > 5.0',
        ),
        BeakOperator.gte: (
          priceFilter(BeakOperator.gte, const BeakDoubleValue(5.0)),
          'price >= 5.0',
        ),
        BeakOperator.lt: (
          priceFilter(BeakOperator.lt, const BeakDoubleValue(5.0)),
          'price < 5.0',
        ),
        BeakOperator.lte: (
          priceFilter(BeakOperator.lte, const BeakDoubleValue(5.0)),
          'price <= 5.0',
        ),
        BeakOperator.like: (
          nameFilter(BeakOperator.like, const BeakStringValue('La%')),
          "name LIKE 'La%'",
        ),
        BeakOperator.ilike: (
          nameFilter(BeakOperator.ilike, const BeakStringValue('la%')),
          "name ILIKE 'la%'",
        ),
        BeakOperator.contains: (
          nameFilter(BeakOperator.contains, const BeakStringValue('ase')),
          "name ILIKE '%ase%'",
        ),
        BeakOperator.startsWith: (
          nameFilter(BeakOperator.startsWith, const BeakStringValue('La')),
          "name ILIKE 'La%'",
        ),
        BeakOperator.endsWith: (
          nameFilter(BeakOperator.endsWith, const BeakStringValue('er')),
          "name ILIKE '%er'",
        ),
        BeakOperator.isNull: (
          nameFilter(BeakOperator.isNull, const BeakNullValue()),
          'name IS NULL',
        ),
        BeakOperator.isNotNull: (
          nameFilter(BeakOperator.isNotNull, const BeakNullValue()),
          'name IS NOT NULL',
        ),
        BeakOperator.inList: (
          priceFilter(
            BeakOperator.inList,
            const BeakListValue([BeakDoubleValue(1.0), BeakDoubleValue(2.0)]),
          ),
          'price IN (1.0, 2.0)',
        ),
        BeakOperator.notInList: (
          priceFilter(
            BeakOperator.notInList,
            const BeakListValue([BeakDoubleValue(1.0), BeakDoubleValue(2.0)]),
          ),
          'price NOT IN (1.0, 2.0)',
        ),
        BeakOperator.between: (
          priceFilter(
            BeakOperator.between,
            const BeakListValue([BeakDoubleValue(1.0), BeakDoubleValue(9.0)]),
          ),
          'price BETWEEN 1.0 AND 9.0',
        ),
        BeakOperator.notBetween: (
          priceFilter(
            BeakOperator.notBetween,
            const BeakListValue([BeakDoubleValue(1.0), BeakDoubleValue(9.0)]),
          ),
          'price NOT BETWEEN 1.0 AND 9.0',
        ),
      };
      // The map literal keys keep this exhaustive: adding a BeakOperator
      // value without a case here fails the length check.
      expect(cases, hasLength(BeakOperator.values.length));
      for (final MapEntry(key: operator, value: (filter, fragment))
          in cases.entries) {
        expect(whereFor(filter), fragment, reason: operator.name);
      }
    });

    test('rejects a between filter without exactly two bounds', () {
      expect(
        () => build(
          BeakQuerySpec(
            table: 'products',
            filter: priceFilter(
              BeakOperator.between,
              const BeakListValue([BeakDoubleValue(1.0)]),
            ),
          ),
        ).toSql(),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects list operators without a list value', () {
      expect(
        () => build(
          BeakQuerySpec(
            table: 'products',
            filter: priceFilter(BeakOperator.inList, const BeakDoubleValue(1)),
          ),
        ).toSql(),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('filter trees', () {
    test('nested and/or groups translate with parentheses', () {
      const spec = BeakQuerySpec(
        table: 'products',
        withTrashed: true,
        filter: BeakOrFilter([
          BeakFieldFilter(
            column: ProductColumns.name,
            operator: BeakOperator.eq,
            value: BeakStringValue('Laser'),
          ),
          BeakAndFilter([
            BeakFieldFilter(
              column: ProductColumns.active,
              operator: BeakOperator.eq,
              value: BeakBoolValue(true),
            ),
            BeakFieldFilter(
              column: ProductColumns.price,
              operator: BeakOperator.lt,
              value: BeakDoubleValue(100.0),
            ),
          ]),
        ]),
      );
      expect(
        _withoutPaging(build(spec).toSql()),
        "SELECT id, name, price, active, created_at, category_id FROM products WHERE (name = 'Laser' OR "
        '(active = TRUE AND price < 100.0))',
      );
    });

    test('an empty composite filter adds no WHERE clause', () {
      const spec = BeakQuerySpec(
        table: 'products',
        withTrashed: true,
        filter: BeakAndFilter([]),
      );
      expect(
        _withoutPaging(build(spec).toSql()),
        'SELECT id, name, price, active, created_at, category_id FROM products',
      );
    });

    test('rejects a filter referencing an unknown column', () {
      expect(
        () => build(
          const BeakQuerySpec(
            table: 'products',
            filter: BeakFieldFilter.forKey('bogus', BeakOperator.isNull),
          ),
        ),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('bogus'),
          ),
        ),
      );
    });
  });

  group('soft deletes', () {
    test('scopes soft-deleting models by default', () {
      expect(
        build(const BeakQuerySpec(table: 'products')).toSql(),
        contains('deleted_at IS NULL'),
      );
    });

    test('withTrashed lifts the scope', () {
      expect(
        build(
          const BeakQuerySpec(table: 'products', withTrashed: true),
        ).toSql(),
        isNot(contains('deleted_at')),
      );
    });

    test('never scopes models without soft deletes', () {
      expect(
        build(const BeakQuerySpec(table: 'categories')).toSql(),
        isNot(contains('deleted_at')),
      );
    });
  });

  group('sorts and search', () {
    test('multiple sorts apply in order', () {
      final spec = const BeakQuerySpec(table: 'products', withTrashed: true)
          .orderBy(ProductModel.name)
          .orderBy(ProductModel.price, descending: true);
      expect(build(spec).toSql(), contains('ORDER BY name ASC, price DESC'));
    });

    test('rejects a sort on an unknown column', () {
      expect(
        () => build(
          const BeakQuerySpec(table: 'products', sorts: [BeakSort('bogus')]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('search uses text contains and typed numeric equality', () {
      final spec = const BeakQuerySpec(
        table: 'products',
        withTrashed: true,
      ).searching('beam', [ProductModel.name, ProductModel.price]);
      expect(build(spec).toSql(), contains("(name ILIKE '%beam%')"));
      final numeric = const BeakQuerySpec(
        table: 'products',
        withTrashed: true,
      ).searching('4.5', [ProductModel.name, ProductModel.price]);
      expect(
        build(numeric).toSql(),
        contains("(name ILIKE '%4.5%' OR price = 4.5)"),
      );
    });

    test('a blank search term is ignored', () {
      final spec = const BeakQuerySpec(
        table: 'products',
        withTrashed: true,
      ).searching('   ', [ProductModel.name]);
      expect(
        _withoutPaging(build(spec).toSql()),
        'SELECT id, name, price, active, created_at, category_id FROM products',
      );
    });
  });

  group('relation loads', () {
    test('registers one eager path per load, including nested dot paths', () {
      final builder = build(
        const BeakQuerySpec(
          table: 'products',
          withTrashed: true,
          relationLoads: [
            BeakRelationLoad(
              'category',
              nested: [BeakRelationLoad('products')],
            ),
            BeakRelationLoad('tags'),
          ],
        ),
      );
      expect(builder.eagerLoads, hasLength(2));
    });

    test('rejects an unknown relation key', () {
      expect(
        () => build(
          const BeakQuerySpec(
            table: 'products',
            relationLoads: [BeakRelationLoad('bogus')],
          ),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('table resolution', () {
    test('rejects a spec for an unregistered table', () {
      expect(
        () => build(const BeakQuerySpec(table: 'unicorns')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('aggregate specs', () {
    test('count/sum/avg run against the in-memory adapter', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'products',
          values: {'id': 1, 'name': 'A', 'price': 10.0, 'active': true},
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'products',
          values: {'id': 2, 'name': 'B', 'price': 30.0, 'active': false},
        ),
      );

      final builder = translator.aggregateBuilderFor(
        const BeakAggregateSpec.count(table: 'products'),
        adapter,
      );
      expect(await builder.count(), 2);
    });

    test('aggregate filters and soft-delete scoping apply', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'products',
          values: {'id': 1, 'price': 10.0, 'active': true},
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'products',
          values: {
            'id': 2,
            'price': 30.0,
            'active': true,
            'deleted_at': '2026-01-01',
          },
        ),
      );

      final scoped = translator.aggregateBuilderFor(
        const BeakAggregateSpec.count(table: 'products'),
        adapter,
      );
      expect(await scoped.count(), 1, reason: 'soft-deleted row excluded');

      final trashed = translator.aggregateBuilderFor(
        const BeakAggregateSpec.count(table: 'products', withTrashed: true),
        adapter,
      );
      expect(await trashed.count(), 2, reason: 'withTrashed sees both');
    });
  });
}
