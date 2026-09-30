import 'package:beak/migrations.dart';

import '../models/delivery_profile.dart';

/// Creates the delivery_profiles table.
///
/// Derived from DeliveryProfileModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDeliveryProfilesTable extends Migration {
  /// Creates the migration.
  const CreateDeliveryProfilesTable();

  @override
  String get name => '20260927_071040_create_delivery_profiles_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('delivery_profiles', (table) {
      BeakBlueprint.defineColumns(table, const DeliveryProfileModel());
      BeakBlueprint.defineForeignKeys(table, const DeliveryProfileModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('delivery_profiles', ifExists: true);
}
