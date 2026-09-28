@TestOn('vm')
library;

import 'package:beak/migrations.dart';
import 'package:clean_beak_config/beak/server.g.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/seeders/shop_seeder.dart';
import 'package:test/test.dart';

/// The catalog references the additive migration declares, as
/// `table.column -> parent (on delete)`.
const _catalogReferences = {
  'products.category_id -> categories (SET NULL)',
  'products.tax_rate_id -> tax_rates (SET NULL)',
  'order_items.variant_id -> product_variants (RESTRICT)',
  'order_items.tax_rate_id -> tax_rates (RESTRICT)',
};

/// Every foreign-key constraint SQLite enforces on the catalog tables.
Future<Set<String>> _references(DatabaseAdapter adapter) async => {
  for (final table in ['products', 'order_items'])
    for (final key in await adapter.rawQuery(
      'SELECT * FROM pragma_foreign_key_list(?)',
      [table],
    ))
      '$table.${key['from']} -> ${key['table']} (${key['on_delete']})',
};

void main() {
  test('a fresh database declares every catalog reference', () async {
    final host = beakHost(
      environment: const {
        'DATABASE_URL': 'sqlite::memory:',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    final adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    addTearDown(() async {
      await adapter.disconnect();
      await Worm.reset();
    });

    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
    ).fresh();

    expect(await _references(adapter), containsAll(_catalogReferences));
  });

  test(
    'additive shop upgrade preserves legacy records and seeding preserves edits',
    () async {
      final host = beakHost(
        environment: const {
          'DATABASE_URL': 'sqlite::memory:',
          'BEAK_STORAGE_DRIVER': 'none',
        },
      );
      final adapter = adapterFromUrl(host.config.databaseUrl);
      await adapter.connect();
      addTearDown(() async {
        await adapter.disconnect();
        await Worm.reset();
      });
      final legacy = host.migrations
          .takeWhile(
            (migration) => !migration.name.contains('create_categories_table'),
          )
          .toList();
      await MigrationRunner(adapter: adapter, migrations: legacy).migrate();
      final oldSchema = await adapter.introspectSchema();
      expect(oldSchema['products'], isNot(contains('category_id')));
      expect(oldSchema['orders'], isNot(contains('status')));
      await adapter.insert(
        const InsertDescriptor(
          table: 'products',
          values: {
            'id': ShopSeedIds.beans,
            'name': 'My existing beans',
            'price': 17.25,
          },
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'orders',
          values: {
            'id': '00000000-0000-4000-8000-000000000090',
            'reference': 'LEGACY-001',
            'delivery_date': '2025-01-01T00:00:00.000Z',
          },
        ),
      );
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: host.migrations,
      );
      final applied = await runner.migrate();
      expect(applied, contains('20260926_235900_expand_shop_catalog'));
      expect(
        applied.any((name) => name.endsWith('create_product_images_table')),
        true,
      );
      expect(
        applied.any(
          (name) => name.endsWith('create_fulfillment_policies_table'),
        ),
        true,
      );
      final schema = await adapter.introspectSchema();
      expect(
        schema['products'],
        containsAll(['category_id', 'tax_rate_id', 'active']),
      );
      expect(schema['order_items'], containsAll(['variant_id', 'tax_rate_id']));
      expect(schema['product_variants'], contains('combination_key'));
      expect(
        await _references(adapter),
        containsAll(_catalogReferences),
        reason:
            'An upgraded database enforces the same references as a '
            'fresh one.',
      );
      for (final model in beakModels) {
        for (final relation in model.relationships) {
          switch (relation) {
            case BeakBelongsTo(:final foreignKey):
              expect(
                schema[model.table],
                contains(foreignKey),
                reason: '${model.table}.${relation.key}',
              );
            case BeakHasMany(:final foreignKey):
              expect(
                schema[relation.relatedTable],
                contains(foreignKey),
                reason: '${model.table}.${relation.key}',
              );
            default:
              break;
          }
        }
      }
      final order = await adapter.selectOne(
        const QueryDescriptor(table: 'orders'),
      );
      expect(order?['reference'], 'LEGACY-001');
      expect(order?['status'], 'draft');
      await const ShopSeeder().run(adapter);
      final beans = await adapter.selectOne(
        QueryDescriptor(
          table: 'products',
          where: const Field<String>('id').eq(ShopSeedIds.beans),
        ),
      );
      expect(beans?['name'], 'My existing beans');
      expect(beans?['price'], 17.25);
      final sampleOrder = await adapter.selectOne(
        QueryDescriptor(
          table: 'orders',
          where: const Field<String>('id').eq(ShopSeedIds.order),
        ),
      );
      expect(sampleOrder?['status'], 'confirmed');
      expect(sampleOrder?['customer_id'], ShopSeedIds.ada);
      expect(sampleOrder?['profile_id'], ShopSeedIds.adaProfile);
      final sampleLines = await adapter.select(
        QueryDescriptor(
          table: 'order_items',
          where: const Field<String>('order_id').eq(ShopSeedIds.order),
        ),
      );
      expect(sampleLines, hasLength(2));
      expect(
        sampleLines.any(
          (line) => line['variant_id'] == ShopSeedIds.filterCoffeeSmall,
        ),
        isTrue,
      );
      expect(
        sampleLines.any(
          (line) =>
              line['product_id'] == null && line['overwrite_price'] == 4.5,
        ),
        isTrue,
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'orders',
          values: const {'status': 'packing'},
          where: const Field<String>('id').eq(ShopSeedIds.order),
        ),
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'invoices',
          values: const {'status': 'paid'},
          where: const Field<String>('id').eq(ShopSeedIds.invoice),
        ),
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'product_variants',
          values: const {'price': 80.0},
          where: const Field<String>('id').eq(ShopSeedIds.filterCoffeeLarge),
        ),
      );
      await const ShopSeeder().run(adapter);
      expect(await runner.migrate(), isEmpty);
      final invoice = await adapter.selectOne(
        QueryDescriptor(
          table: 'invoices',
          where: const Field<String>('id').eq(ShopSeedIds.invoice),
        ),
      );
      expect(invoice?['status'], 'paid');
      expect(
        invoice?['total_cents'],
        12469,
        reason:
            'The original invoice snapshot survives changed catalog prices.',
      );
      expect(
        await adapter.select(const QueryDescriptor(table: 'invoice_items')),
        hasLength(2),
      );
      expect(
        await adapter.select(const QueryDescriptor(table: 'invoice_vouchers')),
        hasLength(2),
      );
      final variant = await adapter.selectOne(
        QueryDescriptor(
          table: 'product_variants',
          where: const Field<String>('id').eq(ShopSeedIds.filterCoffeeLarge),
        ),
      );
      expect(variant?['price'], 80.0);
      final retainedOrder = await adapter.selectOne(
        QueryDescriptor(
          table: 'orders',
          where: const Field<String>('id').eq(ShopSeedIds.order),
        ),
      );
      expect(retainedOrder?['status'], 'packing');
      expect(retainedOrder?['delivery_date'], sampleOrder?['delivery_date']);
      expect(
        await adapter.select(const QueryDescriptor(table: 'orders')),
        hasLength(2),
        reason: 'The legacy order and sample each remain once.',
      );
      expect(
        await adapter.select(const QueryDescriptor(table: 'order_items')),
        hasLength(2),
      );
    },
  );
}
