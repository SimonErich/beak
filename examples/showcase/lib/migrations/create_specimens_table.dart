import 'package:beak/migrations.dart';

import '../resources/specimens/models/specimen.dart';

/// Creates the specimens table.
///
/// Derived from SpecimenModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateSpecimensTable extends Migration {
  /// Creates the migration.
  const CreateSpecimensTable();

  @override
  String get name => '20260929_055001_create_specimens_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('specimens', (table) {
      BeakBlueprint.defineColumns(table, const SpecimenModel());
      BeakBlueprint.defineForeignKeys(table, const SpecimenModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('specimens', ifExists: true);
}
