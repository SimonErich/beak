import 'package:beak/migrations.dart';

import '../models/order_item.dart';

/// Creates the order_items table.
///
/// Derived from OrderItemModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderItemsTable extends Migration {
  /// Creates the migration.
  const CreateOrderItemsTable();

  @override
  String get name => '20260727_152058_create_order_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('order_items', (table) {
      BeakBlueprint.defineColumns(table, const OrderItemModel());
      BeakBlueprint.defineForeignKeys(table, const OrderItemModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_items', ifExists: true);
}
