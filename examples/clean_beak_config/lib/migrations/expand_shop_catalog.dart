import 'package:beak/migrations.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../resources/products/models/product.dart';
import '../resources/orders/models/order_item.dart';
import '../resources/orders/models/order.dart';

/// Adds catalog links without dropping tables or replacing existing data.
final class ExpandShopCatalog extends Migration {
  /// Creates the additive migration.
  const ExpandShopCatalog();

  @override
  String get name => '20260926_235900_expand_shop_catalog';

  @override
  Future<void> upSchema(Schema schema) async {
    final existing = await schema.adapter.introspectSchema();
    Future<void> add(
      String tableName,
      BeakColumn column, {
      String? target,
      OnDelete onDelete = OnDelete.setNull,
    }) async {
      if (existing[tableName]?.contains(column.key) ?? false) return;
      if (target != null && schema.adapter is SqliteAdapter) {
        // SQLite supports a nullable inline reference when adding a column,
        // although it cannot add a stand-alone constraint to an existing table.
        final action = onDelete == OnDelete.restrict ? 'RESTRICT' : 'SET NULL';
        await schema.adapter.rawExecute(
          'ALTER TABLE "$tableName" ADD COLUMN "${column.key}" TEXT REFERENCES "$target" ("id") ON DELETE $action',
          [],
        );
        await schema.alter(tableName, (table) => table.index([column.key]));
      } else {
        await schema.alter(tableName, (table) {
          BeakBlueprint.defineColumn(
            table,
            column,
            isForeignKey: target != null,
            columnDefaults: const {'active': true},
          );
          if (target != null) {
            table.index([column.key]);
            table.foreign(
              column: column.key,
              references: 'id',
              onTable: target,
              onDelete: onDelete,
            );
          }
        });
      }
    }

    await add('orders', OrderColumns.status);
    await add('orders', OrderColumns.notes);
    await add('products', ProductColumns.sku);
    await add('products', ProductColumns.description);
    await add('products', ProductColumns.active);
    await add('products', ProductColumns.categoryId, target: 'categories');
    await add('products', ProductColumns.taxRateId, target: 'tax_rates');
    await add(
      'order_items',
      OrderItemColumns.variantId,
      target: 'product_variants',
      onDelete: OnDelete.restrict,
    );
    await add(
      'order_items',
      OrderItemColumns.taxRateId,
      target: 'tax_rates',
      onDelete: OnDelete.restrict,
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    throw IrreversibleMigrationException(
      migration: name,
      message:
          'Catalog expansion preserves existing shop data; rollback requires an explicit data migration.',
    );
  }
}
