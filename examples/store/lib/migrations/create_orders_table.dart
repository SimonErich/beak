import 'package:beak/migrations.dart';

import '../models/order.dart';

/// Creates the orders table.
///
/// Derived from OrderModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrdersTable extends Migration {
  /// Creates the migration.
  const CreateOrdersTable();

  @override
  String get name => '20260727_152056_create_orders_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('orders', (table) {
      BeakBlueprint.defineColumns(table, const OrderModel());
      BeakBlueprint.defineForeignKeys(table, const OrderModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('orders', ifExists: true);
}
