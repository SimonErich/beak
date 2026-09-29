import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/data/worm/beak_record_keys.dart';
import 'package:beak_backend/src/data/worm/query_translator.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/test_models.dart';

/// A column the model does not declare never leaves the database through
/// Beak: SELECT and RETURNING lists name the declared columns and belongs-to
/// foreign keys, and every hydrated record keeps only those keys, related
/// records included.
void main() {
  late InMemoryAdapter adapter;
  late WormDataSource dataSource;
  final registry = createTestRegistry();

  setUp(() async {
    adapter = await createTestDatabase();
    dataSource = WormDataSource(registry, adapter: adapter);
    // Rows as another writer left them: every table carries a `secret`
    // column no Beak model declares.
    await adapter.insert(
      const InsertDescriptor(
        table: 'categories',
        values: {'id': 1, 'name': 'Optics', 'secret': 'category-secret'},
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'products',
        values: {
          'id': 1,
          'name': 'Laser',
          'price': 9.5,
          'active': true,
          'category_id': 1,
          'secret': 'product-secret',
        },
      ),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'reviews',
        values: {
          'id': 1,
          'product_id': 1,
          'rating': 5,
          'body': 'Bright.',
          'secret': 'review-secret',
        },
      ),
    );
    await adapter.insert(
      const InsertDescriptor(table: 'tags', values: {'id': 1, 'name': 'sale'}),
    );
    await adapter.insert(
      const InsertDescriptor(
        table: 'product_tag',
        values: {'product_id': 1, 'tag_id': 1},
      ),
    );
  });
  tearDown(Worm.reset);

  void expectNoSecret(BeakRecord record) {
    expect(record.values.keys, isNot(contains('secret')));
    for (final related in record.relations.values.expand((list) => list)) {
      expectNoSecret(related);
    }
  }

  test('beakRecordKeys: declared columns plus belongs-to foreign keys', () {
    expect(beakRecordKeys(const ProductModel()), [
      'id',
      'name',
      'price',
      'active',
      'created_at',
      'category_id',
    ]);
    expect(
      identical(
        beakRecordKeys(const ProductModel()),
        beakRecordKeys(const ProductModel()),
      ),
      isTrue,
      reason: 'computed once per model',
    );
  });

  test('query, getOne and batchGet never carry an undeclared column', () async {
    final page = await dataSource.query(
      const BeakQuerySpec(
        table: 'products',
        relationLoads: [
          BeakRelationLoad('category'),
          BeakRelationLoad('reviews'),
          BeakRelationLoad('tags'),
        ],
      ),
    );
    expect(page.items.single.relations.keys, {'category', 'reviews', 'tags'});
    expectNoSecret(page.items.single);
    expectNoSecret((await dataSource.getOne('products', 1))!);
    for (final record in await dataSource.batchGet('products', [1])) {
      expectNoSecret(record);
    }
  });

  test('the SELECT names its columns (no SELECT *)', () {
    final sql = WormQueryTranslator(
      registry,
    ).builderFor(const BeakQuerySpec(table: 'products'), adapter).toSql();
    expect(sql, startsWith('SELECT id, name, price, active, created_at'));
  });

  test('create echoes declared columns even when a row held more', () async {
    final created = await dataSource.create(
      'categories',
      BeakRecord.fromRow({'id': 2, 'name': 'Lenses', 'secret': 'planted'}),
    );
    expect(created.values.keys.toSet(), {'id', 'name'});
  });

  test('a graph commit persists only declared keys in its receipt', () async {
    await const BeakCommitReceiptsMigration().up(adapter);
    final commits = BeakGraphCommitService(
      registry: registry,
      source: dataSource,
    );

    final result = await commits.commit(
      BeakSavePlan(
        saveId: 'rename',
        root: const BeakRecordRef.existing('products', 1),
        operations: [
          BeakSaveOperation(
            id: 'product',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('products', 1),
            values: BeakRecord.fromRow({'name': 'Laser XL'}),
          ),
        ],
      ),
    );

    expect(result.complete, isTrue);
    expect(result.rootRecord?['name']?.raw, 'Laser XL');
    final receipt = await adapter.selectOne(
      const QueryDescriptor(table: BeakCommitReceiptsMigration.table),
    );
    expect(receipt?['result_json'], contains('Laser XL'));
    expect(receipt?['result_json'], isNot(contains('product-secret')));
    expect(receipt?['request_json'], isNot(contains('product-secret')));
  });
}
