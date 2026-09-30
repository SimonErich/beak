import 'package:beak/migrations.dart';

import '../resources/orders/models/order_discount.dart';

/// Creates the order_discounts table.
///
/// Derived from OrderDiscountModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderDiscountsTable extends Migration {
  /// Creates the migration.
  const CreateOrderDiscountsTable();

  @override
  String get name => '20260926_201257_create_order_discounts_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('order_discounts', (table) {
      BeakBlueprint.defineColumns(table, const OrderDiscountModel());
      BeakBlueprint.defineForeignKeys(table, const OrderDiscountModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_discounts', ifExists: true);
}
