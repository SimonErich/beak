import 'package:beak/migrations.dart';

import '../resources/taxes/models/tax_rate.dart';

/// Creates the tax_rates table.
///
/// Derived from TaxRateModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateTaxRatesTable extends Migration {
  /// Creates the migration.
  const CreateTaxRatesTable();

  @override
  String get name => '20260926_213336_create_tax_rates_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('tax_rates', (table) {
      BeakBlueprint.defineColumns(table, const TaxRateModel());
      BeakBlueprint.defineForeignKeys(table, const TaxRateModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tax_rates', ifExists: true);
}
