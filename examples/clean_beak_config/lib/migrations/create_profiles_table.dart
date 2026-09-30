import 'package:beak/migrations.dart';

import '../resources/profiles/models/profile.dart';

/// Creates the profiles table.
///
/// Derived from ProfileModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProfilesTable extends Migration {
  /// Creates the migration.
  const CreateProfilesTable();

  @override
  String get name => '20260926_201254_create_profiles_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('profiles', (table) {
      BeakBlueprint.defineColumns(table, const ProfileModel());
      BeakBlueprint.defineForeignKeys(table, const ProfileModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('profiles', ifExists: true);
}
