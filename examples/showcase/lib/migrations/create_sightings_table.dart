import 'package:beak/migrations.dart';

import '../resources/sightings/models/sighting.dart';

/// Creates the sightings table.
///
/// Derived from SightingModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateSightingsTable extends Migration {
  /// Creates the migration.
  const CreateSightingsTable();

  @override
  String get name => '20260929_055000_create_sightings_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('sightings', (table) {
      BeakBlueprint.defineColumns(table, const SightingModel());
      BeakBlueprint.defineForeignKeys(table, const SightingModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('sightings', ifExists: true);
}
