import 'package:beak/migrations.dart';

import '../models/order_item_option.dart';

/// Creates the order_item_options table.
///
/// Derived from OrderItemOptionModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderItemOptionsTable extends Migration {
  /// Creates the migration.
  const CreateOrderItemOptionsTable();

  @override
  String get name => '20260927_071055_create_order_item_options_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('order_item_options', (table) {
      BeakBlueprint.defineColumns(table, const OrderItemOptionModel());
      BeakBlueprint.defineForeignKeys(table, const OrderItemOptionModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_item_options', ifExists: true);
}
