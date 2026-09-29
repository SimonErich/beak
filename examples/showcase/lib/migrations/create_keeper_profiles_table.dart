import 'package:beak/migrations.dart';

import '../resources/keepers/models/keeper_profile.dart';

/// Creates the keeper_profiles table.
///
/// Derived from KeeperProfileModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateKeeperProfilesTable extends Migration {
  /// Creates the migration.
  const CreateKeeperProfilesTable();

  @override
  String get name => '20260929_054956_create_keeper_profiles_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('keeper_profiles', (table) {
      BeakBlueprint.defineColumns(table, const KeeperProfileModel());
      BeakBlueprint.defineForeignKeys(table, const KeeperProfileModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('keeper_profiles', ifExists: true);
}
