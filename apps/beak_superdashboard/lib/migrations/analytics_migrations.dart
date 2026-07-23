import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

import 'model_schema.dart';

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
      defineModelColumns(table, const TimeSeriesPointModel());
      table.index(['series']);
    });
    await schema.create(
      'purchase_sources',
      (table) => defineModelColumns(table, const PurchaseSourceModel()),
    );
    await schema.create(
      'country_stats',
      (table) => defineModelColumns(table, const CountryStatModel()),
    );
    await schema.create(
      'price_candles',
      (table) => defineModelColumns(table, const PriceCandleModel()),
    );
    await schema.create(
      'activity_heatmap',
      (table) => defineModelColumns(table, const ActivityHeatCellModel()),
    );
    await schema.create(
      'office_locations',
      (table) => defineModelColumns(table, const OfficeLocationModel()),
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

/// Companion upgrade for databases migrated before `activity_heatmap` gained
/// `sort_index`: the create migration derives its columns from the model, so
/// pre-existing databases (whose create already ran under the same name)
/// would otherwise never receive the column and the heatmap's ORDER BY would
/// fail with an undefined column.
final class AddSortIndexToActivityHeatmap extends Migration {
  /// Creates the migration.
  const AddSortIndexToActivityHeatmap();

  @override
  String get name => '20260723_000100_add_sort_index_to_activity_heatmap';

  @override
  List<String> get dependsOn => const [
    '20260707_000300_create_analytics_tables',
  ];

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    try {
      await adapter.rawExecute(
        'ALTER TABLE "activity_heatmap" '
        'ADD COLUMN IF NOT EXISTS "sort_index" integer NOT NULL DEFAULT 0',
        const [],
      );
    } on UnsupportedOperationException {
      // Non-SQL adapters (the in-memory test adapter) always create the
      // table fresh from the model, which already includes sort_index.
    }
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {
    try {
      await adapter.rawExecute(
        'ALTER TABLE "activity_heatmap" DROP COLUMN IF EXISTS "sort_index"',
        const [],
      );
    } on UnsupportedOperationException {
      // See up(): nothing to revert on non-SQL adapters.
    }
  }
}
