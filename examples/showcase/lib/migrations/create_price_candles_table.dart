import 'package:beak/migrations.dart';

import '../resources/candles/models/price_candle.dart';

/// Creates the price_candles table.
///
/// Derived from PriceCandleModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreatePriceCandlesTable extends Migration {
  /// Creates the migration.
  const CreatePriceCandlesTable();

  @override
  String get name => '20260929_054950_create_price_candles_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('price_candles', (table) {
      BeakBlueprint.defineColumns(table, const PriceCandleModel());
      BeakBlueprint.defineForeignKeys(table, const PriceCandleModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('price_candles', ifExists: true);
}
