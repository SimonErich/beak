import 'package:beak/migrations.dart';

import '../models/tag.dart';

/// Creates the tags table.
///
/// Derived from TagModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateTagsTable extends Migration {
  /// Creates the migration.
  const CreateTagsTable();

  @override
  String get name => '20260727_152100_create_tags_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('tags', (table) {
      BeakBlueprint.defineColumns(table, const TagModel());
      BeakBlueprint.defineForeignKeys(table, const TagModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tags', ifExists: true);
}
