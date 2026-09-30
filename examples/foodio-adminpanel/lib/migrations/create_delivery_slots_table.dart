import 'package:beak/migrations.dart';

import '../models/delivery_slot.dart';

/// Creates the delivery_slots table.
///
/// Derived from DeliverySlotModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDeliverySlotsTable extends Migration {
  /// Creates the migration.
  const CreateDeliverySlotsTable();

  @override
  String get name => '20260927_071042_create_delivery_slots_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('delivery_slots', (table) {
      BeakBlueprint.defineColumns(table, const DeliverySlotModel());
      BeakBlueprint.defineForeignKeys(table, const DeliverySlotModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('delivery_slots', ifExists: true);
}
