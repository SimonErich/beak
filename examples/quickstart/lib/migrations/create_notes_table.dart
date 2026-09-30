import 'package:beak/migrations.dart';

import '../resources/notes/models/note.dart';

/// Creates the notes table.
///
/// Derived from NoteModel the first time `beak prepare` ran, and yours from
/// then on: Beak never rewrites a migration it has written.
final class CreateNotesTable extends Migration {
  /// Creates the migration.
  const CreateNotesTable();

  @override
  String get name => '20260727_160744_create_notes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model when this runs, so a database that has not run it
    // yet gets the table the model describes today. One that already has does
    // not change: a field added later reaches it with a migration of its own,
    // `beak make:migration <Name> --from-drift`.
    await schema.create('notes', (table) {
      BeakBlueprint.defineColumns(table, const NoteModel());
      BeakBlueprint.defineForeignKeys(table, const NoteModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('notes', ifExists: true);
}
