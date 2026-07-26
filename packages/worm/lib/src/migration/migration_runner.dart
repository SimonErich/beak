/// Migration executor with batch tracking.
library;

import '../adapter/database_adapter.dart';
import '../exception/migration_exception.dart';
import '../schema/schema_facade.dart';
import '../seeder/environment.dart';
import '../seeder/seeder_base.dart';
import '../seeder/seeder_runner.dart';
import 'migration_base.dart';
import 'migration_dependency_sorter.dart';
import 'migration_record.dart';
import 'migration_record_store.dart';
import 'migration_status.dart';
import 'pretend_recorder.dart';

/// Coordinates running, rolling back, and reporting migrations
/// against a [DatabaseAdapter].
///
/// `MigrationRunner` is also the orchestration point for the
/// `migrate:fresh --seed` workflow: when constructed with a list of
/// [seeders], calling [fresh] with `seed: true` runs the registered
/// seeders against the same adapter once the migration log has been
/// rebuilt. Leaving [seeders] empty keeps the runner pure for the
/// CLI's other paths (`migrate`, `migrate:rollback`, …).
final class MigrationRunner {
  /// Creates a [MigrationRunner].
  MigrationRunner({
    required this.adapter,
    required List<Migration> migrations,
    this.seeders = const <Seeder>[],
    this.environment = Environment.development,
  }) : migrations = MigrationDependencySorter.sort(migrations),
       _store = MigrationRecordStore(adapter);

  /// Adapter the runner targets.
  final DatabaseAdapter adapter;

  /// Migrations in execution order.
  ///
  /// [MigrationDependencySorter] honours every `dependsOn` declaration and
  /// otherwise keeps the order they were registered in — it does **not**
  /// re-sort by [Migration.name]. A caller that relies on timestamp ordering
  /// must register them in that order.
  final List<Migration> migrations;

  /// Seeders consulted by [fresh] when `seed: true`. Empty by
  /// default — non-CLI callers that never seed can omit it.
  final List<Seeder> seeders;

  /// Active runtime environment, forwarded to the [SeederRunner]
  /// built by [fresh] when seeding is requested. Drives the
  /// per-seeder environment gate.
  final Environment environment;

  final MigrationRecordStore _store;

  /// Apply pending migrations in a single batch.
  ///
  /// When [step] is `null` every pending migration is applied; when
  /// non-null only the first [step] pending migrations run. The
  /// applied migrations all share one batch number — `max(batch) + 1`.
  /// Returns the names of newly-applied migrations.
  Future<List<String>> migrate({int? step}) async {
    await _store.ensureTable();
    final applied = await _store.appliedNames();
    final pending = migrations.where((m) => !applied.contains(m.name)).toList();
    if (pending.isEmpty) return const <String>[];
    final toApply = step == null ? pending : pending.take(step).toList();
    if (toApply.isEmpty) return const <String>[];
    final batch = (await _store.maxBatch()) + 1;
    final out = <String>[];
    for (final m in toApply) {
      await _runUp(m);
      await _store.insert(m.name, batch);
      out.add(m.name);
    }
    return out;
  }

  /// Capture the SQL-ish output of every pending migration without
  /// executing it. Returns the captured statements per migration.
  Future<Map<String, List<String>>> pretend() async {
    await _store.ensureTable();
    final applied = await _store.appliedNames();
    final pending = migrations.where((m) => !applied.contains(m.name)).toList();
    final out = <String, List<String>>{};
    for (final m in pending) {
      final recorder = PretendAdapter(adapter);
      await m.upSchema(Schema.forRunner(recorder));
      out[m.name] = recorder.statements;
    }
    return out;
  }

  /// Roll back the most recent [steps] batches. Defaults to one
  /// batch (the classic `migrate:rollback`). Returns the rolled-back
  /// names in the order they were reverted. With no applied
  /// migrations this is a no-op.
  Future<List<String>> rollback({int steps = 1}) async {
    await _store.ensureTable();
    final out = <String>[];
    for (var i = 0; i < steps; i++) {
      final lastBatch = await _store.maxBatch();
      if (lastBatch == 0) break;
      final names = await _store.namesInBatch(lastBatch);
      for (final name in names) {
        final migration = _byName(name);
        await _runDown(migration);
        await _store.remove(name);
        out.add(name);
      }
    }
    return out;
  }

  /// Roll back **every** applied migration, then re-apply all.
  Future<void> refresh() async {
    while ((await _store.maxBatch()) > 0) {
      await rollback();
    }
    await migrate();
  }

  /// Drop the tracking table and re-apply every migration from
  /// scratch. Schema-level destructive — caller must gate on
  /// `--force` in production.
  ///
  /// When [seed] is `true`, the configured [seeders] run against
  /// the adapter after the fresh re-apply completes. The runner
  /// filters seeders by their declared [Environment] using a
  /// [SeederRunner]. Returns the names of every seeder that ran
  /// (empty when `seed: false` or when no seeder is registered for
  /// the active environment).
  Future<List<String>> fresh({bool seed = false}) async {
    await _store.dropTable();
    await _store.ensureTable();
    for (final m in migrations) {
      await _runUp(m);
      await _store.insert(m.name, 1);
    }
    if (!seed) return const <String>[];
    return _runSeeders();
  }

  /// Alias for [migrate]. Provided so call sites can read
  /// `runner.run(step: 2)` matching the CLI surface naming.
  Future<List<String>> run({int? step}) => migrate(step: step);

  Future<List<String>> _runSeeders() => SeederRunner(
    adapter: adapter,
    seeders: seeders,
    environment: environment,
  ).run();

  /// Report pending / applied state for every registered migration.
  Future<List<MigrationStatus>> status() async {
    await _store.ensureTable();
    final byName = <String, MigrationRecord>{
      for (final r in await _store.all()) r.name: r,
    };
    return <MigrationStatus>[
      for (final m in migrations)
        if (byName[m.name] case final MigrationRecord record)
          MigrationStatus(
            name: m.name,
            state: MigrationState.applied,
            batch: record.batch,
          )
        else
          MigrationStatus(name: m.name, state: MigrationState.pending),
    ];
  }

  Future<void> _runUp(Migration m) async {
    try {
      await m.upSchema(Schema.forRunner(adapter));
    } on Object catch (error) {
      throw MigrationException(
        migration: m.name,
        message: 'up() failed: $error',
      );
    }
  }

  Future<void> _runDown(Migration m) async {
    try {
      await m.downSchema(Schema.forRunner(adapter));
    } on Object catch (error) {
      throw MigrationException(
        migration: m.name,
        message: 'down() failed: $error',
      );
    }
  }

  Migration _byName(String name) {
    for (final m in migrations) {
      if (m.name == name) return m;
    }
    throw MigrationException(
      migration: name,
      message: 'Recorded migration not present in registered list',
    );
  }
}
