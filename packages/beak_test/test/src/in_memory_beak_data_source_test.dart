import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

import '../support/contract_models.dart';

const _product = ProductModel();
const _category = CategoryModel();
const _tag = TagModel();

InMemoryBeakDataSource sourceWith({DateTime Function()? now}) =>
    InMemoryBeakDataSource(
      registry: buildContractRegistry(),
      now: now ?? () => DateTime.utc(2026, 7, 26, 12),
      generateId: () => 'generated-id',
    );

BeakRecord product(
  String id, {
  String name = 'Item',
  double price = 10,
  int stock = 1,
  String? categoryId,
  DateTime? deletedAt,
}) => BeakRecord(
  values: {
    'id': BeakValue.of(id),
    'name': BeakValue.of(name),
    'price': BeakValue.of(price),
    'stock': BeakValue.of(stock),
    'status': const BeakStringValue('draft'),
    'category_id': BeakValue.of(categoryId),
    'deleted_at': BeakValue.of(deletedAt),
  },
);

void main() {
  // The full interface contract, run against the reference implementation.
  runBeakDataSourceContract(
    'InMemoryBeakDataSource',
    registry: buildContractRegistry(),
    model: _product,
    create: () async => sourceWith(),
    seed: (source, model, records) async =>
        (source as InMemoryBeakDataSource).seed(model, records),
    sortableTextColumn: ProductColumns.name,
    numericColumn: ProductColumns.price,
  );

  group('operators', () {
    late InMemoryBeakDataSource source;

    setUp(() {
      source = sourceWith()
        ..seed(_product, [
          product('1', name: 'Espresso', price: 10, stock: 5),
          product('2', name: 'Latte', price: 20, stock: 0),
          product('3', name: 'Mocha', price: 30, stock: 15),
        ]);
    });

    Future<List<String>> matching(BeakFilter filter) async {
      final page = await source.query(_product.query(filter: filter));
      return [for (final record in page.items) '${record['id']?.raw}'];
    }

    BeakFilter on(BeakColumn column, BeakOperator operator, Object? value) =>
        BeakFieldFilter(
          column: column,
          operator: operator,
          value: BeakValue.of(value),
        );

    test('comparison operators order numerically, not lexically', () async {
      // '30' < '5' as strings; the source must compare as numbers.
      expect(await matching(on(ProductColumns.stock, BeakOperator.gt, 5)), [
        '3',
      ]);
      expect(await matching(on(ProductColumns.stock, BeakOperator.gte, 5)), [
        '1',
        '3',
      ]);
      expect(await matching(on(ProductColumns.stock, BeakOperator.lt, 5)), [
        '2',
      ]);
      expect(await matching(on(ProductColumns.stock, BeakOperator.lte, 5)), [
        '1',
        '2',
      ]);
    });

    test('between is inclusive at both bounds', () async {
      expect(
        await matching(
          on(ProductColumns.price, BeakOperator.between, [10, 20]),
        ),
        ['1', '2'],
      );
      expect(
        await matching(
          on(ProductColumns.price, BeakOperator.notBetween, [10, 20]),
        ),
        ['3'],
      );
    });

    test('between rejects a wrong number of bounds', () {
      expect(
        () => matching(on(ProductColumns.price, BeakOperator.between, [10])),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test(
      'text operators distinguish case where the operator says so',
      () async {
        expect(
          await matching(on(ProductColumns.name, BeakOperator.contains, 'sso')),
          ['1'],
        );
        expect(
          await matching(
            on(ProductColumns.name, BeakOperator.like, 'espresso'),
          ),
          isEmpty,
        );
        expect(
          await matching(
            on(ProductColumns.name, BeakOperator.ilike, 'espresso'),
          ),
          ['1'],
        );
        expect(
          await matching(
            on(ProductColumns.name, BeakOperator.startsWith, 'La'),
          ),
          ['2'],
        );
        expect(
          await matching(on(ProductColumns.name, BeakOperator.endsWith, 'cha')),
          ['3'],
        );
      },
    );

    test('null operators find absent and present values', () async {
      expect(
        await matching(
          on(ProductColumns.categoryId, BeakOperator.isNull, null),
        ),
        ['1', '2', '3'],
      );
      source.seed(_product, [product('4', categoryId: 'c1')]);
      expect(
        await matching(
          on(ProductColumns.categoryId, BeakOperator.isNotNull, null),
        ),
        ['4'],
      );
    });

    test('nested and/or compose', () async {
      final filter = BeakAndFilter([
        on(ProductColumns.price, BeakOperator.gte, 10),
        BeakOrFilter([
          on(ProductColumns.name, BeakOperator.eq, 'Espresso'),
          on(ProductColumns.name, BeakOperator.eq, 'Mocha'),
        ]),
      ]);
      expect(await matching(filter), ['1', '3']);
    });
  });

  group('sorting', () {
    test('nulls sort last in both directions', () async {
      final source = sourceWith()
        ..seed(_product, [
          product('1', categoryId: 'b'),
          product('2'),
          product('3', categoryId: 'a'),
        ]);

      Future<List<String>> ordered({required bool descending}) async {
        final page = await source.query(
          _product.query(
            sorts: [
              BeakSort(ProductColumns.categoryId.key, descending: descending),
            ],
          ),
        );
        return [for (final record in page.items) '${record['id']?.raw}'];
      }

      expect(await ordered(descending: false), ['3', '1', '2']);
      expect(await ordered(descending: true), ['1', '3', '2']);
    });

    test('a second sort key breaks ties', () async {
      final source = sourceWith()
        ..seed(_product, [
          product('1', name: 'A', stock: 2),
          product('2', name: 'A', stock: 1),
          product('3', name: 'B', stock: 9),
        ]);
      final page = await source.query(
        _product.query(
          sorts: [
            BeakSort(ProductColumns.name.key),
            BeakSort(ProductColumns.stock.key),
          ],
        ),
      );
      expect([for (final r in page.items) '${r['id']?.raw}'], ['2', '1', '3']);
    });
  });

  group('relations', () {
    late InMemoryBeakDataSource source;

    setUp(() {
      source = sourceWith()
        ..seed(_category, [
          const BeakRecord(
            values: {
              'id': BeakStringValue('c1'),
              'name': BeakStringValue('Coffee'),
            },
          ),
        ])
        ..seed(_tag, [
          const BeakRecord(
            values: {
              'id': BeakStringValue('t1'),
              'name': BeakStringValue('Hot'),
            },
          ),
          const BeakRecord(
            values: {
              'id': BeakStringValue('t2'),
              'name': BeakStringValue('New'),
            },
          ),
        ])
        ..seed(_product, [product('1', categoryId: 'c1')])
        ..seedPivot(ProductRelations.tags, '1', ['t1', 't2']);
    });

    test('belongs-to loads the single owner', () async {
      final page = await source.query(
        _product.query(relationLoads: const [BeakRelationLoad('category')]),
      );
      expect(page.items.single.relations['category'], hasLength(1));
      expect(
        page.items.single.relations['category']!.single['name']?.raw,
        'Coffee',
      );
    });

    test('belongs-to-many loads through the pivot', () async {
      final page = await source.query(
        _product.query(relationLoads: const [BeakRelationLoad('tags')]),
      );
      expect(page.items.single.relations['tags'], hasLength(2));
    });

    test('has-many loads the inverse side', () async {
      final page = await source.query(
        _category.query(relationLoads: const [BeakRelationLoad('products')]),
      );
      expect(page.items.single.relations['products'], hasLength(1));
    });

    test('a relation load can be filtered', () async {
      final page = await source.query(
        _product.query(
          relationLoads: [
            const BeakRelationLoad(
              'tags',
              filter: BeakFieldFilter(
                column: CategoryColumns.name,
                operator: BeakOperator.eq,
                value: BeakStringValue('Hot'),
              ),
            ),
          ],
        ),
      );
      expect(page.items.single.relations['tags'], hasLength(1));
    });

    test('nested loads resolve two levels deep', () async {
      final page = await source.query(
        _category.query(
          relationLoads: const [
            BeakRelationLoad(
              'products',
              nested: [BeakRelationLoad('category')],
            ),
          ],
        ),
      );
      final nested = page.items.single.relations['products']!.single;
      expect(nested.relations['category'], hasLength(1));
    });

    test('an unknown relation is a configuration error', () {
      expect(
        () => source.query(
          _product.query(relationLoads: const [BeakRelationLoad('nope')]),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('attach and detach', () {
    late InMemoryBeakDataSource source;

    setUp(() {
      source = sourceWith()
        ..seed(_product, [product('1')])
        ..seed(_tag, [
          const BeakRecord(
            values: {
              'id': BeakStringValue('t1'),
              'name': BeakStringValue('Hot'),
            },
          ),
        ]);
    });

    Future<int> tagCount() async {
      final page = await source.query(
        _product.query(relationLoads: const [BeakRelationLoad('tags')]),
      );
      return page.items.single.relations['tags']?.length ?? 0;
    }

    test('attach links, detach unlinks, both idempotent', () async {
      await source.attach('products', '1', 'tags', ['t1']);
      await source.attach('products', '1', 'tags', ['t1']);
      expect(await tagCount(), 1, reason: 'attaching twice links once');

      await source.detach('products', '1', 'tags', ['t1']);
      await source.detach('products', '1', 'tags', ['t1']);
      expect(await tagCount(), 0);
    });

    test('detaching from an untouched pivot is a no-op', () async {
      await source.detach('products', '1', 'tags', ['t1']);
      expect(await tagCount(), 0);
    });

    test('a non-pivot relation cannot be attached', () {
      expect(
        () => source.attach('products', '1', 'category', ['c1']),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('not a\nmany-to-many'.replaceAll('\n', ' ')),
          ),
        ),
      );
    });

    test('an unknown relation cannot be attached', () {
      expect(
        () => source.attach('products', '1', 'nope', ['x']),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('writes', () {
    test('create stamps created_at and updated_at when declared', () async {
      // The fixture model declares neither, so nothing is stamped; a model
      // that declares them gets them. Asserted through rowsOf to see storage.
      final source = sourceWith();
      final created = await source.create('products', product('x'));
      expect(created['id']?.raw, 'x');
      expect(source.rowsOf('products'), hasLength(1));
    });

    test('create mints an id when the payload omits one entirely', () async {
      // A convenience of *this* source, not part of the shared contract:
      // BeakResourceService owns id minting, but the in-memory source is
      // also used standalone (a panel with no backend), where nothing else
      // would assign one.
      final source = sourceWith();
      final created = await source.create(
        'products',
        const BeakRecord(values: {'name': BeakStringValue('x')}),
      );
      expect(created['id']?.raw, 'generated-id');
    });

    test('create mints an id when the payload has an empty one', () async {
      final source = sourceWith();
      final created = await source.create(
        'products',
        const BeakRecord(
          values: {'id': BeakStringValue(''), 'name': BeakStringValue('x')},
        ),
      );
      expect(created['id']?.raw, 'generated-id');
    });

    test('soft delete writes the marker and hides the row', () async {
      final source = sourceWith()..seed(_product, [product('1')]);
      await source.delete('products', '1');

      expect(await source.getOne('products', '1'), isNull);
      expect(
        source.rowsOf('products').single['deleted_at']?.raw,
        DateTime.utc(2026, 7, 26, 12),
        reason: 'the row is still stored, just marked',
      );
    });

    test('a hard-deleting model removes the row outright', () async {
      final source = sourceWith()
        ..seed(_category, [
          const BeakRecord(
            values: {
              'id': BeakStringValue('c1'),
              'name': BeakStringValue('Coffee'),
            },
          ),
        ]);
      await source.delete('categories', 'c1');
      expect(source.rowsOf('categories'), isEmpty);
    });

    test('updating a soft-deleted row is a not-found', () async {
      final source = sourceWith()..seed(_product, [product('1')]);
      await source.delete('products', '1');
      expect(
        () => source.update(
          'products',
          '1',
          const BeakRecord(values: {'name': BeakStringValue('x')}),
        ),
        throwsA(isA<BeakNotFoundException>()),
      );
    });
  });

  group('seeding', () {
    test('rejects a record with no primary key', () {
      expect(
        () => sourceWith().seed(_product, [
          const BeakRecord(values: {'name': BeakStringValue('x')}),
        ]),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('"id"'),
          ),
        ),
      );
    });

    test('replaces rather than appends', () {
      final source = sourceWith()
        ..seed(_product, [product('1')])
        ..seed(_product, [product('2')]);
      expect(source.rowsOf('products'), hasLength(1));
    });

    test('rowsOf is unmodifiable', () {
      final source = sourceWith()..seed(_product, [product('1')]);
      expect(
        () => source.rowsOf('products').add(product('2')),
        throwsUnsupportedError,
      );
    });
  });

  group('aggregates', () {
    test('withTrashed includes soft-deleted rows', () async {
      final source = sourceWith()
        ..seed(_product, [
          product('1'),
          product('2', deletedAt: DateTime.utc(2026)),
        ]);
      expect(await source.aggregate(_product.count()), 1);
      expect(await source.aggregate(_product.count(withTrashed: true)), 2);
    });
  });
}
