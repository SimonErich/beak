import 'package:beak/migrations.dart';

import '../models/delivery_location.dart';

/// Creates the delivery_locations table.
///
/// Derived from DeliveryLocationModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDeliveryLocationsTable extends Migration {
  /// Creates the migration.
  const CreateDeliveryLocationsTable();

  @override
  String get name => '20260927_071038_create_delivery_locations_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('delivery_locations', (table) {
      BeakBlueprint.defineColumns(table, const DeliveryLocationModel());
      BeakBlueprint.defineForeignKeys(table, const DeliveryLocationModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('delivery_locations', ifExists: true);
}
