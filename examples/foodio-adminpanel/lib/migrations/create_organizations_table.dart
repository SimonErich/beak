import 'package:beak/migrations.dart';

import '../models/organization.dart';

/// Creates the organizations table.
///
/// Derived from OrganizationModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateOrganizationsTable extends Migration {
  /// Creates the migration.
  const CreateOrganizationsTable();

  @override
  String get name => '20260927_071037_create_organizations_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('organizations', (table) {
      BeakBlueprint.defineColumns(table, const OrganizationModel());
      BeakBlueprint.defineForeignKeys(table, const OrganizationModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('organizations', ifExists: true);
}
