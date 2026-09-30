import 'package:beak/migrations.dart';

import '../resources/companies/models/company.dart';

/// Creates the companies table.
///
/// Derived from CompanyModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateCompaniesTable extends Migration {
  /// Creates the migration.
  const CreateCompaniesTable();

  @override
  String get name => '20260926_201252_create_companies_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('companies', (table) {
      BeakBlueprint.defineColumns(table, const CompanyModel());
      BeakBlueprint.defineForeignKeys(table, const CompanyModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('companies', ifExists: true);
}
