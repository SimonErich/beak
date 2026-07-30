import 'package:superdashboard/models/models.dart';
import 'package:beak/migrations.dart';

/// Creates the Analytics domain: FK-free aggregate tables that back the
/// dashboard charts and map.
final class CreateAnalyticsTables extends Migration {
  /// Creates the migration.
  const CreateAnalyticsTables();

  @override
  String get name => '20260707_000300_create_analytics_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('time_series_points', (table) {
      BeakBlueprint.defineColumns(table, const TimeSeriesPointModel());
      table.index(['series']);
    });
    await schema.create(
      'purchase_sources',
      (table) =>
          BeakBlueprint.defineColumns(table, const PurchaseSourceModel()),
    );
    await schema.create(
      'country_stats',
      (table) => BeakBlueprint.defineColumns(table, const CountryStatModel()),
    );
    await schema.create(
      'price_candles',
      (table) => BeakBlueprint.defineColumns(table, const PriceCandleModel()),
    );
    await schema.create(
      'activity_heatmap',
      (table) =>
          BeakBlueprint.defineColumns(table, const ActivityHeatCellModel()),
    );
    await schema.create(
      'office_locations',
      (table) =>
          BeakBlueprint.defineColumns(table, const OfficeLocationModel()),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'office_locations',
      'activity_heatmap',
      'price_candles',
      'country_stats',
      'purchase_sources',
      'time_series_points',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
