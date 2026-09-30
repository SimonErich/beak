import 'package:beak/migrations.dart';

import '../resources/users/models/user.dart';

/// Creates the users table.
///
/// Derived from UserModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateUsersTable extends Migration {
  /// Creates the migration.
  const CreateUsersTable();

  @override
  String get name => '20260926_201253_create_users_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('users', (table) {
      BeakBlueprint.defineColumns(table, const UserModel());
      BeakBlueprint.defineForeignKeys(table, const UserModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('users', ifExists: true);
}
