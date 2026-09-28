import 'package:beak/migrations.dart';

import '../resources/products/models/variant_attribute.dart';

/// Creates the variant_attributes table.
///
/// Derived from VariantAttributeModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateVariantAttributesTable extends Migration {
  /// Creates the migration.
  const CreateVariantAttributesTable();

  @override
  String get name => '20260926_213342_create_variant_attributes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('variant_attributes', (table) {
      BeakBlueprint.defineColumns(table, const VariantAttributeModel());
      BeakBlueprint.defineForeignKeys(table, const VariantAttributeModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('variant_attributes', ifExists: true);
}
