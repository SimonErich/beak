import 'package:beak/migrations.dart';

import '../models/order_note.dart';

/// Creates the order_notes table.
///
/// Derived from OrderNoteModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrderNotesTable extends Migration {
  /// Creates the migration.
  const CreateOrderNotesTable();

  @override
  String get name => '20260927_071056_create_order_notes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('order_notes', (table) {
      BeakBlueprint.defineColumns(table, const OrderNoteModel());
      BeakBlueprint.defineForeignKeys(table, const OrderNoteModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_notes', ifExists: true);
}
