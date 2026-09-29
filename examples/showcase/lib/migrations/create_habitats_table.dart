import 'package:beak/migrations.dart';

import '../resources/habitats/models/habitat.dart';

/// Creates the habitats table.
///
/// Derived from HabitatModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateHabitatsTable extends Migration {
  /// Creates the migration.
  const CreateHabitatsTable();

  @override
  String get name => '20260929_054952_create_habitats_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('habitats', (table) {
      BeakBlueprint.defineColumns(table, const HabitatModel());
      BeakBlueprint.defineForeignKeys(table, const HabitatModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('habitats', ifExists: true);
}
