import 'package:beak/migrations.dart';

import '../models/note.dart';

/// Creates the notes table.
///
/// Derived from NoteModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateNotesTable extends Migration {
  /// Creates the migration.
  const CreateNotesTable();

  @override
  String get name => '20260727_160744_create_notes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('notes', (table) {
      BeakBlueprint.defineColumns(table, const NoteModel());
      BeakBlueprint.defineForeignKeys(table, const NoteModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('notes', ifExists: true);
}
