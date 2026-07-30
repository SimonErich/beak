import 'package:beak/migrations.dart';

import '../models/roast_profile.dart';

/// Creates the roast_profiles table.
///
/// Derived from RoastProfileModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateRoastProfilesTable extends Migration {
  /// Creates the migration.
  const CreateRoastProfilesTable();

  @override
  String get name => '20260727_152059_create_roast_profiles_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('roast_profiles', (table) {
      BeakBlueprint.defineColumns(table, const RoastProfileModel());
      BeakBlueprint.defineForeignKeys(table, const RoastProfileModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('roast_profiles', ifExists: true);
}
