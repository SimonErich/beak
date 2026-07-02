/// Seeder executor that honors environment filtering, explicit
/// ordering, and idempotent tracking via [SeederRecordStore].
library;

import '../adapter/database_adapter.dart';
import '../registry/worm.dart';
import 'environment.dart';
import 'seeder_base.dart';
import 'seeder_record_store.dart';

/// Runs registered seeders against an adapter.
final class SeederRunner {
  /// Creates a [SeederRunner] for [adapter].
  ///
  /// Pass [store] to enable idempotent tracking. With a store
  /// the runner consults `hasRun(seeder.name)` before invoking
  /// each seeder and records the run on success.
  const SeederRunner({
    required this.adapter,
    required this.seeders,
    required this.environment,
    this.store,
  });

  /// Adapter the runner targets.
  final DatabaseAdapter adapter;

  /// Registered seeders, in declared order.
  final List<Seeder> seeders;

  /// Current runtime environment.
  final Environment environment;

  /// Optional tracking store. When set, seeders run idempotently
  /// — already-recorded seeders are skipped and successful runs
  /// are persisted to `worm_seeders`.
  final SeederRecordStore? store;

  /// Whether [seeder] is allowed to run in the current environment.
  bool shouldRun(Seeder seeder) =>
      seeder.environment == Environment.all ||
      seeder.environment == environment;

  /// Run seeders against the configured adapter and return the names
  /// that actually ran.
  ///
  /// * `seederClass` — when non-null, runs only the seeder whose
  ///   [Seeder.name] matches and skips the environment filter.
  /// * `force` — when `true`, skips the environment filter for every
  ///   seeder. Has no effect when `seederClass` is set.
  ///
  /// When a [store] is configured the runner ensures the tracking
  /// table exists, skips any seeder whose name already has a
  /// record, and inserts a record after each successful run.
  Future<List<String>> run({String? seederClass, bool force = false}) async {
    final tracker = store;
    if (tracker != null) await tracker.ensureTable();
    if (seederClass != null) {
      return _runOne(_findByName(seederClass), tracker);
    }
    final ordered = _orderedSeeders();
    final out = <String>[];
    for (final s in ordered) {
      if (!force && !shouldRun(s)) continue;
      if (tracker != null && await tracker.hasRun(s.name)) continue;
      await _invoke(s);
      if (tracker != null) await tracker.record(s.name);
      out.add(s.name);
    }
    return out;
  }

  /// Run [seeder], muting lifecycle events when it opts in.
  Future<void> _invoke(Seeder seeder) async {
    if (seeder.muteEvents) {
      await Worm.withoutEvents(() => seeder.run(adapter));
    } else {
      await seeder.run(adapter);
    }
  }

  /// Thin alias kept for older call sites that prefer the
  /// action-named surface. New code should use [run] with
  /// `seederClass:`.
  Future<void> runOne(String name) async {
    await run(seederClass: name);
  }

  Future<List<String>> _runOne(
    Seeder seeder,
    SeederRecordStore? tracker,
  ) async {
    if (tracker != null && await tracker.hasRun(seeder.name)) {
      return <String>[];
    }
    await _invoke(seeder);
    if (tracker != null) await tracker.record(seeder.name);
    return <String>[seeder.name];
  }

  List<Seeder> _orderedSeeders() {
    final indexed =
        <(int, Seeder)>[
          for (var i = 0; i < seeders.length; i++) (i, seeders[i]),
        ]..sort((a, b) {
          final byOrder = a.$2.order.compareTo(b.$2.order);
          if (byOrder != 0) return byOrder;
          return a.$1.compareTo(b.$1);
        });
    return <Seeder>[for (final pair in indexed) pair.$2];
  }

  Seeder _findByName(String name) {
    for (final s in seeders) {
      if (s.name == name) return s;
    }
    throw ArgumentError.value(name, 'seederClass', 'No seeder registered');
  }
}
