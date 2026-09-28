import 'package:beak/migrations.dart';

import '../resources/orders/models/order_item.dart';

/// Creates the order_items table.
///
/// Derived from OrderItemModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderItemsTable extends Migration {
  /// Creates the migration.
  const CreateOrderItemsTable();

  @override
  String get name => '20260926_201259_create_order_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Preserve the original migration on both existing and fresh databases.
    await schema.create('order_items', (table) {
      table.idUuid();
      for (final column in [
        OrderItemColumns.label,
        OrderItemColumns.quantity,
        OrderItemColumns.overwritePrice,
        OrderItemColumns.discount,
      ]) {
        BeakBlueprint.defineColumn(table, column);
      }
      BeakBlueprint.defineColumn(
        table,
        OrderItemColumns.orderId,
        isForeignKey: true,
      );
      BeakBlueprint.defineColumn(
        table,
        OrderItemColumns.productId,
        isForeignKey: true,
      );
      table.index(['order_id']);
      table.index(['product_id']);
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.restrict,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_items', ifExists: true);
}
