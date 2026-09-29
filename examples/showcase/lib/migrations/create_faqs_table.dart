import 'package:beak/migrations.dart';

import '../resources/faqs/models/faq.dart';

/// Creates the faqs table.
///
/// Derived from FaqModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateFaqsTable extends Migration {
  /// Creates the migration.
  const CreateFaqsTable();

  @override
  String get name => '20260929_054951_create_faqs_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('faqs', (table) {
      BeakBlueprint.defineColumns(table, const FaqModel());
      BeakBlueprint.defineForeignKeys(table, const FaqModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('faqs', ifExists: true);
}
