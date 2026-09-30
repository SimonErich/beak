import 'package:beak/migrations.dart';

import '../models/order_activity.dart';

/// Creates the order_activities table.
///
/// Derived from OrderActivityModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderActivitiesTable extends Migration {
  /// Creates the migration.
  const CreateOrderActivitiesTable();

  @override
  String get name => '20260927_071053_create_order_activities_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('order_activities', (table) {
      BeakBlueprint.defineColumns(table, const OrderActivityModel());
      BeakBlueprint.defineForeignKeys(table, const OrderActivityModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_activities', ifExists: true);
}
