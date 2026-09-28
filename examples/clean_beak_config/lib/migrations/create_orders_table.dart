import 'package:beak/migrations.dart';

import '../resources/orders/models/order.dart';

/// Creates the orders table.
///
/// Derived from OrderModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrdersTable extends Migration {
  /// Creates the migration.
  const CreateOrdersTable();

  @override
  String get name => '20260926_201256_create_orders_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Preserve the original shape; later migrations add status and notes.
    await schema.create('orders', (table) {
      table.idUuid();
      BeakBlueprint.defineColumn(table, OrderColumns.reference);
      BeakBlueprint.defineColumn(table, OrderColumns.deliveryDate);
      for (final column in [OrderColumns.customerId, OrderColumns.profileId]) {
        BeakBlueprint.defineColumn(table, column, isForeignKey: true);
        table.index([column.key]);
      }
      BeakBlueprint.defineForeignKeys(table, const OrderModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('orders', ifExists: true);
}
