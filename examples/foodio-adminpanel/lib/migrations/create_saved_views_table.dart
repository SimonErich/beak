import 'package:beak/migrations.dart';

import '../models/saved_view.dart';

/// Creates the saved_views table.
///
/// Derived from SavedViewModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateSavedViewsTable extends Migration {
  /// Creates the migration.
  const CreateSavedViewsTable();

  @override
  String get name => '20260927_071057_create_saved_views_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('saved_views', (table) {
      BeakBlueprint.defineColumns(table, const SavedViewModel());
      BeakBlueprint.defineForeignKeys(table, const SavedViewModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('saved_views', ifExists: true);
}
