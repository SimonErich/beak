import 'package:beak/migrations.dart';

import '../models/ticket.dart';

/// Creates the tickets table.
///
/// Derived from TicketModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateTicketsTable extends Migration {
  /// Creates the migration.
  const CreateTicketsTable();

  @override
  String get name => '20260727_160920_create_tickets_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('tickets', (table) {
      BeakBlueprint.defineColumns(table, const TicketModel());
      BeakBlueprint.defineForeignKeys(table, const TicketModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tickets', ifExists: true);
}
