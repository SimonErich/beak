import 'package:beak_superdashboard/models/models.dart';

import 'seed_context.dart';

/// Seeds the Analytics domain by **rolling up the rows the commerce seeder
/// inserted**, so the dashboard's charts, donut, and map reconcile exactly
/// with the underlying orders — nothing is invented.
final class AnalyticsSeeder {
  /// Creates the seeder.
  const AnalyticsSeeder();

  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const Map<String, String> _sourceLabels = {
    'direct': 'Direct',
    'social': 'Social',
    'email': 'Email',
    'affiliate': 'Affiliate',
    'search': 'Search',
  };

  static const Map<String, String> _sourceColors = {
    'direct': '#4f46e5',
    'social': '#0ea5e9',
    'email': '#10b981',
    'affiliate': '#f59e0b',
    'search': '#8b5cf6',
  };

  /// Seeds all Analytics-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final orders = await ctx.selectAll('orders');
    final users = await ctx.selectAll('users');
    await _seedTimeSeries(ctx, orders);
    await _seedPurchaseSources(ctx, orders);
    await _seedCountryStats(ctx, orders, users);
  }

  // Postgres returns `decimal` columns as strings, the in-memory adapter as
  // numbers — parse both so the roll-up works against either backend.
  double _totalOf(Map<String, Object?> order) => switch (order['total']) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? 0,
    _ => 0,
  };

  Future<void> _seedTimeSeries(
    SeedContext ctx,
    List<Map<String, Object?>> orders,
  ) async {
    // Twelve rolling month buckets ending at the reference month.
    final months = <DateTime>[
      for (var back = 11; back >= 0; back--)
        DateTime.utc(SeedContext.now.year, SeedContext.now.month - back),
    ];
    final revenue = <String, double>{};
    final counts = <String, int>{};
    String key(DateTime date) => '${date.year}-${date.month}';
    for (final month in months) {
      revenue[key(month)] = 0;
      counts[key(month)] = 0;
    }
    for (final order in orders) {
      final placedAt = order['placed_at'];
      if (placedAt is! DateTime) {
        continue;
      }
      final bucket = key(DateTime.utc(placedAt.year, placedAt.month));
      if (revenue.containsKey(bucket)) {
        revenue[bucket] = revenue[bucket]! + _totalOf(order);
        counts[bucket] = counts[bucket]! + 1;
      }
    }

    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < months.length; index++) {
      final month = months[index];
      final label = _monthLabels[month.month - 1];
      rows.add(
        _point(
          ctx,
          'sales_revenue',
          label,
          month,
          index,
          double.parse(revenue[key(month)]!.toStringAsFixed(2)),
        ),
      );
      rows.add(
        _point(
          ctx,
          'sales_orders',
          label,
          month,
          index,
          counts[key(month)]!.toDouble(),
        ),
      );
      // Audience series are illustrative visitor counts, not order-derived.
      rows.add(
        _point(
          ctx,
          'audience_organic',
          label,
          month,
          index,
          ctx.between(1800, 4200).toDouble(),
        ),
      );
      rows.add(
        _point(
          ctx,
          'audience_social',
          label,
          month,
          index,
          ctx.between(900, 2600).toDouble(),
        ),
      );
    }
    await ctx.insertMany('time_series_points', rows);
  }

  Map<String, Object?> _point(
    SeedContext ctx,
    String series,
    String label,
    DateTime month,
    int sortIndex,
    double value,
  ) => {
    'id': ctx.uuid(),
    'series': series,
    'label': label,
    'value': value,
    'bucket_date': month,
    'sort_index': sortIndex,
  };

  Future<void> _seedPurchaseSources(
    SeedContext ctx,
    List<Map<String, Object?>> orders,
  ) async {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final source in PurchaseSource.values) {
      totals[source.name] = 0;
      counts[source.name] = 0;
    }
    var grandTotal = 0.0;
    for (final order in orders) {
      final source = order['source']! as String;
      final total = _totalOf(order);
      totals[source] = (totals[source] ?? 0) + total;
      counts[source] = (counts[source] ?? 0) + 1;
      grandTotal += total;
    }

    final rows = <Map<String, Object?>>[];
    for (final source in PurchaseSource.values) {
      final total = totals[source.name]!;
      rows.add({
        'id': ctx.uuid(),
        'source': source.name,
        'label': _sourceLabels[source.name],
        'total': double.parse(total.toStringAsFixed(2)),
        'count': counts[source.name],
        'percent': grandTotal == 0
            ? 0.0
            : double.parse((total / grandTotal * 100).toStringAsFixed(1)),
        'color': _sourceColors[source.name],
      });
    }
    await ctx.insertMany('purchase_sources', rows);
  }

  Future<void> _seedCountryStats(
    SeedContext ctx,
    List<Map<String, Object?>> orders,
    List<Map<String, Object?>> users,
  ) async {
    final codeByUser = <String, String>{};
    final nameByCode = <String, String>{};
    final activeByCode = <String, int>{};
    for (final user in users) {
      final code = user['country_code'];
      if (code is! String || code.isEmpty) {
        continue;
      }
      codeByUser[user['id']! as String] = code;
      nameByCode[code] = user['country']! as String;
      activeByCode[code] = (activeByCode[code] ?? 0) + 1;
    }
    final salesByCode = <String, double>{};
    for (final order in orders) {
      final code = codeByUser[order['user_id']];
      if (code == null) {
        continue;
      }
      salesByCode[code] = (salesByCode[code] ?? 0) + _totalOf(order);
    }

    final rows = <Map<String, Object?>>[
      for (final entry in activeByCode.entries)
        {
          'id': ctx.uuid(),
          'country': nameByCode[entry.key],
          'country_code': entry.key,
          'active_users': entry.value,
          'sales': double.parse(
            (salesByCode[entry.key] ?? 0).toStringAsFixed(2),
          ),
          'change_percent': ctx.money(-12, 28),
        },
    ];
    await ctx.insertMany('country_stats', rows);
  }
}
