import 'package:beak/migrations.dart';

import '../resources/keepers/models/keeper.dart';

/// Creates the keepers table.
///
/// Derived from KeeperModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateKeepersTable extends Migration {
  /// Creates the migration.
  const CreateKeepersTable();

  @override
  String get name => '20260929_054953_create_keepers_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('keepers', (table) {
      BeakBlueprint.defineColumns(table, const KeeperModel());
      BeakBlueprint.defineForeignKeys(table, const KeeperModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('keepers', ifExists: true);
}
