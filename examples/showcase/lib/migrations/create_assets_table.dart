import 'package:beak/migrations.dart';

import '../resources/assets/models/asset.dart';

/// Creates the assets table.
///
/// Derived from AssetModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateAssetsTable extends Migration {
  /// Creates the migration.
  const CreateAssetsTable();

  @override
  String get name => '20260929_054949_create_assets_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('assets', (table) {
      BeakBlueprint.defineColumns(table, const AssetModel());
      BeakBlueprint.defineForeignKeys(table, const AssetModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('assets', ifExists: true);
}
