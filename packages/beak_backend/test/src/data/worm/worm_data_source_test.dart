import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

void main() {
  late InMemoryAdapter inner;
  late InMemoryQueryLogger logger;
  late WormDataSource dataSource;

  final fixedNow = DateTime.utc(2026, 7, 3, 12);

  setUp(() async {
    Worm.seedRandom(42);
    inner = await createTestDatabase();
    logger = InMemoryQueryLogger();
    dataSource = WormDataSource(
      createTestRegistry(),
      adapter: LoggingAdapter(
        inner: inner,
        logger: logger,
        strictness: const StrictnessConfig(),
        adapterName: 'InMemory',
      ),
      now: () => fixedNow,
    );
  });

  tearDown(Worm.reset);

  BeakRecord product({
    required int id,
    required String name,
    double price = 10.0,
    bool active = true,
    int? categoryId,
  }) => BeakRecord.fromRow({
    'id': id,
    'name': name,
    'price': price,
    'active': active,
    'category_id': categoryId,
  });

  Future<void> seedRelatedWorld() async {
    await inner.insert(
      const InsertDescriptor(
        table: 'categories',
        values: {'id': 7, 'name': 'Toys'},
      ),
    );
    await dataSource.create(
      'products',
      product(id: 1, name: 'Laser Pointer', categoryId: 7),
    );
    await dataSource.create(
      'products',
      product(id: 2, name: 'Beam Splitter', price: 99.0, categoryId: 7),
    );
    await inner.insert(
      const InsertDescriptor(
        table: 'reviews',
        values: {'id': 1, 'product_id': 1, 'rating': 5, 'body': 'Cat approved'},
      ),
    );
    await inner.insert(
      const InsertDescriptor(table: 'tags', values: {'id': 1, 'name': 'toys'}),
    );
    await inner.insert(
      const InsertDescriptor(
        table: 'tags',
        values: {'id': 2, 'name': 'lasers'},
      ),
    );
    await inner.insert(
      const InsertDescriptor(
        table: 'product_tag',
        values: {'product_id': 1, 'tag_id': 1},
      ),
    );
    await inner.insert(
      const InsertDescriptor(
        table: 'product_tag',
        values: {'product_id': 1, 'tag_id': 2},
      ),
    );
  }

  group('create / getOne / update / delete', () {
    test('round-trips a full record lifecycle', () async {
      final created = await dataSource.create(
        'products',
        product(id: 1, name: 'Laser Pointer'),
      );
      expect(created['name'], const BeakStringValue('Laser Pointer'));

      final fetched = await dataSource.getOne('products', 1);
      expect(fetched, isNotNull);
      expect(fetched?['price'], const BeakDoubleValue(10.0));

      final updated = await dataSource.update(
        'products',
        1,
        BeakRecord.fromRow(const {'name': 'Laser Pointer XL', 'price': 12.5}),
      );
      expect(updated['name'], const BeakStringValue('Laser Pointer XL'));
      expect(updated['price'], const BeakDoubleValue(12.5));

      await dataSource.delete('products', 1, force: true);
      expect(await dataSource.getOne('products', 1), isNull);
    });

    test('getOne returns null for a missing id', () async {
      expect(await dataSource.getOne('products', 404), isNull);
    });

    test('update of a missing record throws not-found', () {
      expect(
        () => dataSource.update(
          'products',
          404,
          BeakRecord.fromRow(const {'name': 'Ghost'}),
        ),
        throwsA(isA<BeakNotFoundException>()),
      );
    });

    test('delete of a missing record throws not-found', () {
      expect(
        () => dataSource.delete('products', 404),
        throwsA(isA<BeakNotFoundException>()),
      );
    });

    test('unknown tables throw configuration failures', () {
      expect(
        () => dataSource.getOne('unicorns', 1),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('soft deletes', () {
    test(
      'delete without force soft-deletes and queries hide the record',
      () async {
        await dataSource.create('products', product(id: 1, name: 'Laser'));
        await dataSource.delete('products', 1);

        expect(await dataSource.getOne('products', 1), isNull);

        final visible = await dataSource.query(
          const BeakQuerySpec(table: 'products'),
        );
        expect(visible.items, isEmpty);
        expect(visible.total, 0);

        final trashed = await dataSource.query(
          const BeakQuerySpec(table: 'products', withTrashed: true),
        );
        expect(trashed.items, hasLength(1));
        expect(trashed.items.single['deleted_at'], BeakDateTimeValue(fixedNow));
      },
    );

    test('force delete removes a soft-deleted record for good', () async {
      await dataSource.create('products', product(id: 1, name: 'Laser'));
      await dataSource.delete('products', 1);
      await dataSource.delete('products', 1, force: true);

      final trashed = await dataSource.query(
        const BeakQuerySpec(table: 'products', withTrashed: true),
      );
      expect(trashed.items, isEmpty);
    });

    test('hard-deleting models delete physically from the start', () async {
      await inner.insert(
        const InsertDescriptor(
          table: 'categories',
          values: {'id': 1, 'name': 'Toys'},
        ),
      );
      await dataSource.delete('categories', 1);
      final page = await dataSource.query(
        const BeakQuerySpec(table: 'categories', withTrashed: true),
      );
      expect(page.items, isEmpty);
    });
  });

  group('query', () {
    test('pages, orders, and reports the full total', () async {
      for (var id = 1; id <= 7; id += 1) {
        await dataSource.create(
          'products',
          product(id: id, name: 'P$id', price: id * 10.0),
        );
      }

      final page = await dataSource.query(
        const BeakQuerySpec(table: 'products')
            .orderBy(ProductColumns.price, descending: true)
            .paginate(page: 2, perPage: 3),
      );

      expect(page.total, 7);
      expect(page.page, 2);
      expect(page.perPage, 3);
      expect(
        [for (final item in page.items) item['name']],
        const [
          BeakStringValue('P4'),
          BeakStringValue('P3'),
          BeakStringValue('P2'),
        ],
      );
    });

    test('eager-loads every requested relation with batched queries', () async {
      await seedRelatedWorld();
      logger.clear();

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [
            BeakRelationLoad('category'),
            BeakRelationLoad('reviews'),
          ],
        ).paginate(page: 1, perPage: 10),
      );

      // 1 count + 1 parent select + 1 belongs-to batch + 1 has-many batch.
      expect(logger.entries, hasLength(4));

      final laser = page.items.firstWhere(
        (item) => item['id'] == const BeakIntValue(1),
      );
      expect(laser.relations['category'], hasLength(1));
      expect(
        laser.relations['category']?.single['name'],
        const BeakStringValue('Toys'),
      );
      expect(laser.relations['reviews'], hasLength(1));

      final beam = page.items.firstWhere(
        (item) => item['id'] == const BeakIntValue(2),
      );
      expect(beam.relations['reviews'], isEmpty);
    });

    test(
      'belongs-to-many loads resolve through the pivot in two queries',
      () async {
        await seedRelatedWorld();
        logger.clear();

        final page = await dataSource.query(
          const BeakQuerySpec(
            table: 'products',
            relationLoads: [BeakRelationLoad('tags')],
          ),
        );

        // 1 count + 1 parent select + 2 for the pivot hop.
        expect(logger.entries, hasLength(4));
        final laser = page.items.firstWhere(
          (item) => item['id'] == const BeakIntValue(1),
        );
        expect(
          {
            for (final tag in laser.relations['tags'] ?? const <BeakRecord>[])
              tag['name'],
          },
          {const BeakStringValue('toys'), const BeakStringValue('lasers')},
        );
      },
    );

    test('a belongs-to with a null foreign key loads as empty', () async {
      await dataSource.create('products', product(id: 1, name: 'Orphan'));

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [BeakRelationLoad('category')],
        ),
      );

      expect(page.items.single.relations['category'], isEmpty);
    });
  });

  group('batchGet', () {
    test('fetches every requested id in exactly one query', () async {
      for (var id = 1; id <= 4; id += 1) {
        await dataSource.create('products', product(id: id, name: 'P$id'));
      }
      logger.clear();

      final records = await dataSource.batchGet('products', const [1, 3]);

      expect(logger.entries, hasLength(1));
      expect(
        {for (final record in records) record['id']},
        {const BeakIntValue(1), const BeakIntValue(3)},
      );
    });

    test('returns empty without querying for an empty id list', () async {
      logger.clear();
      expect(await dataSource.batchGet('products', const []), isEmpty);
      expect(logger.entries, isEmpty);
    });
  });

  group('attach / detach', () {
    setUp(() async {
      await seedRelatedWorld();
    });

    test('attach links only the missing ids', () async {
      await dataSource.attach('products', 2, 'tags', const [1]);
      await dataSource.attach('products', 2, 'tags', const [1, 2]);

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [BeakRelationLoad('tags')],
        ),
      );
      final beam = page.items.firstWhere(
        (item) => item['id'] == const BeakIntValue(2),
      );
      expect(beam.relations['tags'], hasLength(2));
    });

    test('detach removes exactly the requested links', () async {
      await dataSource.detach('products', 1, 'tags', const [1]);

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [BeakRelationLoad('tags')],
        ),
      );
      final laser = page.items.firstWhere(
        (item) => item['id'] == const BeakIntValue(1),
      );
      expect(
        [
          for (final tag in laser.relations['tags'] ?? const <BeakRecord>[])
            tag['name'],
        ],
        const [BeakStringValue('lasers')],
      );
    });

    test('attach rejects relations that are not to-many', () {
      expect(
        () => dataSource.attach('products', 1, 'category', const [7]),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('detach rejects unknown relation keys', () {
      expect(
        () => dataSource.detach('products', 1, 'bogus', const [1]),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('aggregate', () {
    setUp(() async {
      await dataSource.create(
        'products',
        product(id: 1, name: 'A', price: 10.0),
      );
      await dataSource.create(
        'products',
        product(id: 2, name: 'B', price: 30.0, active: false),
      );
    });

    test('count honors filters', () async {
      expect(
        await dataSource.aggregate(
          const BeakAggregateSpec.count(table: 'products'),
        ),
        2,
      );
      expect(
        await dataSource.aggregate(
          BeakAggregateSpec.count(
            table: 'products',
            filter: BeakFieldFilter(
              column: ProductColumns.active,
              operator: BeakOperator.eq,
              value: const BeakBoolValue(true),
            ),
          ),
        ),
        1,
      );
    });

    test('sum and avg push down to the adapter', () async {
      expect(
        await dataSource.aggregate(
          BeakAggregateSpec.sum(
            table: 'products',
            column: ProductColumns.price,
          ),
        ),
        40.0,
      );
      expect(
        await dataSource.aggregate(
          BeakAggregateSpec.avg(
            table: 'products',
            column: ProductColumns.price,
          ),
        ),
        20.0,
      );
    });

    test('sum over no rows returns zero', () async {
      expect(
        await dataSource.aggregate(
          BeakAggregateSpec.sum(
            table: 'products',
            column: ProductColumns.price,
            filter: BeakFieldFilter(
              column: ProductColumns.price,
              operator: BeakOperator.gt,
              value: const BeakDoubleValue(1000.0),
            ),
          ),
        ),
        0,
      );
    });

    test('count excludes soft-deleted rows unless withTrashed', () async {
      await dataSource.delete('products', 1);
      expect(
        await dataSource.aggregate(
          const BeakAggregateSpec.count(table: 'products'),
        ),
        1,
      );
      expect(
        await dataSource.aggregate(
          const BeakAggregateSpec.count(table: 'products', withTrashed: true),
        ),
        2,
      );
    });

    test('sum rejects non-numeric columns', () {
      expect(
        () => dataSource.aggregate(
          BeakAggregateSpec.sum(table: 'products', column: ProductColumns.name),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
