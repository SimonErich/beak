/// Composable master seeder that delegates to child seeders.
library;

import '../adapter/database_adapter.dart';
import 'seeder_base.dart';

/// A seeder that runs other seeders, one after another, in the
/// exact order returned by [seeders].
///
/// Tracking (the `worm_seeders` row) and idempotency are the
/// responsibility of `SeederRunner`. `DatabaseSeeder` itself
/// never writes to the tracking table — it only invokes
/// children's `run` methods in declared order. This keeps
/// composition pure and lets the same children be reused both
/// inside a master and as top-level seeders.
abstract base class DatabaseSeeder extends Seeder {
  /// Const constructor for subclasses.
  const DatabaseSeeder();

  /// Children executed by [run], in declared order.
  ///
  /// Override and return a const list of seeder instances.
  List<Seeder> get seeders;

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    for (final child in seeders) {
      await child.run(adapter);
    }
  }
}
