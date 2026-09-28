import 'package:beak/migrations.dart';

import '../models/complaint.dart';

/// Creates the complaints table.
///
/// Derived from ComplaintModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateComplaintsTable extends Migration {
  /// Creates the migration.
  const CreateComplaintsTable();

  @override
  String get name => '20260927_071047_create_complaints_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('complaints', (table) {
      BeakBlueprint.defineColumns(table, const ComplaintModel());
      BeakBlueprint.defineForeignKeys(table, const ComplaintModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('complaints', ifExists: true);
}
