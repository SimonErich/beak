import 'package:beak/migrations.dart';

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
      // A reference declared in the same alter as its column is additive on
      // every database, SQLite included: it becomes the new column's inline
      // REFERENCES clause, so no table is rebuilt and no row is replaced.
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
