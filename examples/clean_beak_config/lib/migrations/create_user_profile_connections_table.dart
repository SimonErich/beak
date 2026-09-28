import 'package:beak/migrations.dart';

import '../resources/users/models/user_profile_connection.dart';

/// Creates the user_profile_connections table.
///
/// Derived from UserProfileConnectionModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateUserProfileConnectionsTable extends Migration {
  /// Creates the migration.
  const CreateUserProfileConnectionsTable();

  @override
  String get name => '20260926_201255_create_user_profile_connections_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('user_profile_connections', (table) {
      BeakBlueprint.defineColumns(table, const UserProfileConnectionModel());
      BeakBlueprint.defineForeignKeys(
        table,
        const UserProfileConnectionModel(),
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('user_profile_connections', ifExists: true);
}
