import 'package:beak/migrations.dart';

/// The shared toolkit every domain seeder builds on: a deterministically
/// seeded faker, a fixed reference clock, a UUID minter, and thin insert
/// helpers — so the whole database reproduces byte-for-byte across runs.
final class SeedContext {
  /// Creates a context over [adapter] and seeds the faker.
  SeedContext(this.adapter) {
    faker.seed(seed);
  }

  /// The reproducibility seed shared by the faker and every derived value.
  static const int seed = 20260707;

  /// The demo's fixed "now" — every relative date is measured from here so
  /// screens look identical on every run.
  static final DateTime now = DateTime.utc(2026, 7, 7, 12);

  /// The adapter rows are written to.
  final DatabaseAdapter adapter;

  /// The seeded fake-data source.
  final FakerService faker = FakerService.instance;

  /// Inserts one row into [table].
  Future<void> insert(String table, Map<String, Object?> values) =>
      adapter.insert(InsertDescriptor(table: table, values: values));

  /// Inserts many [rows] into [table] in one batch (no-op when empty).
  Future<void> insertMany(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await adapter.insertMany(InsertManyDescriptor(table: table, rows: rows));
  }

  /// Reads back every row of [table] (used by the analytics seeder to derive
  /// its aggregates from the rows other seeders inserted).
  Future<List<Map<String, Object?>>> selectAll(String table) =>
      adapter.select(QueryDescriptor(table: table));

  /// A fresh deterministic UUID.
  String uuid() => faker.uuid();

  /// An inclusive integer in [lo]..[hi].
  int between(int lo, int hi) => faker.intBetween(lo, hi);

  /// A two-decimal amount in [lo]..[hi].
  double money(num lo, num hi) => faker.decimalBetween(lo, hi);

  /// A moment up to [maxDays] before [now].
  DateTime daysAgo(int maxDays) => now.subtract(
    Duration(days: faker.intBetween(0, maxDays), hours: between(0, 23)),
  );

  /// A moment within ±[days] of [now] (for the visible calendar month).
  DateTime around(int days) => now.add(
    Duration(days: faker.intBetween(-days, days), hours: between(6, 20)),
  );

  /// A uniformly random element of [values].
  T pick<T>(List<T> values) => faker.element(values);

  /// A weighted random key of [weights].
  T weighted<T>(Map<T, int> weights) => faker.weighted(weights);

  /// `true` with probability [p].
  bool chance(double p) => faker.boolean(probability: p);
}
