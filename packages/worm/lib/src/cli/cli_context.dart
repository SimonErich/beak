/// Execution context shared by every CLI command.
library;

import 'dart:async';
import 'dart:io';

import '../adapter/database_adapter.dart';
import '../adapter/in_memory_adapter.dart';
import '../migration/migration_base.dart';
import '../seeder/environment.dart';
import '../seeder/seeder_base.dart';

/// Test-friendly factory for the adapter used by destructive
/// commands. The default builds an [InMemoryAdapter] so the CLI is
/// usable without a real database.
typedef AdapterFactory = FutureOr<DatabaseAdapter> Function();

/// Carries the cross-cutting state every CLI command needs.
final class CliContext {
  /// Creates a [CliContext].
  CliContext({
    required this.out,
    required this.err,
    required this.projectRoot,
    required this.environment,
    required this.now,
    required this.adapterFactory,
    this.migrations = const <Migration>[],
    this.seeders = const <Seeder>[],
    this.models = const <ModelInfo>[],
  });

  /// Standard output sink (test seam).
  final StringSink out;

  /// Standard error sink (test seam).
  final StringSink err;

  /// Project root directory the CLI operates on.
  final Directory projectRoot;

  /// Active runtime environment (drives `--force` gating).
  final Environment environment;

  /// Deterministic clock source.
  final DateTime Function() now;

  /// Builds the adapter used by `migrate`, `db:seed`, and friends.
  final AdapterFactory adapterFactory;

  /// Registered migrations (for `migrate` family commands).
  final List<Migration> migrations;

  /// Registered seeders (for `db:seed`).
  final List<Seeder> seeders;

  /// Registered model descriptors (for `model:show`). Each entry
  /// names a model, its table, and the typed fields / relations the
  /// CLI exposes. The runtime registry stores `Type` references that
  /// reflection-free Dart cannot enumerate fields against, so the
  /// CLI surface accepts a richer descriptor here that callers (the
  /// application's `main.dart`) populate explicitly.
  final List<ModelInfo> models;

  /// Convenience: directory `migrations/` under [projectRoot].
  Directory get migrationsDir => Directory('${projectRoot.path}/migrations');

  /// Convenience: directory `seeds/` under [projectRoot].
  Directory get seedsDir => Directory('${projectRoot.path}/seeds');

  /// Convenience: directory `lib/factories/` under [projectRoot].
  ///
  /// Aligned with the layout produced by `worm init`: factories live
  /// under `lib/` so they participate in the package's Dart import
  /// graph rather than sitting at the repo root.
  Directory get factoriesDir => Directory('${projectRoot.path}/lib/factories');

  /// Convenience: directory `lib/models/` under [projectRoot].
  ///
  /// See [factoriesDir] for the rationale behind the `lib/` prefix.
  Directory get modelsDir => Directory('${projectRoot.path}/lib/models');

  /// Whether the runtime environment is production.
  bool get isProduction => environment == Environment.production;

  /// Default in-memory factory for tests and dry runs.
  static FutureOr<DatabaseAdapter> defaultAdapterFactory() {
    final adapter = InMemoryAdapter();
    return Future<DatabaseAdapter>(() async {
      await adapter.connect();
      return adapter;
    });
  }
}

/// One field on a [ModelInfo].
final class ModelField {
  /// Creates a [ModelField].
  const ModelField({required this.name, required this.type});

  /// Field name (also the SQL column name in most cases).
  final String name;

  /// Logical type label (e.g. `'string'`, `'integer'`, `'uuid'`).
  /// A free-form `String` rather than `ColumnType` so projects can
  /// describe types the worm core does not enumerate.
  final String type;
}

/// One relation on a [ModelInfo].
final class ModelRelation {
  /// Creates a [ModelRelation].
  const ModelRelation({
    required this.name,
    required this.kind,
    required this.target,
  });

  /// Accessor name as exposed on the Dart model (e.g. `'posts'`).
  final String name;

  /// Relation kind label (`'hasMany'`, `'belongsTo'`, `'hasOne'`, …).
  final String kind;

  /// Target model class name.
  final String target;
}

/// CLI-side metadata for one model class registered with the worm
/// runtime. Used by `worm model:show` to render the model's table
/// name, field set, and relation graph.
final class ModelInfo {
  /// Creates a [ModelInfo].
  const ModelInfo({
    required this.name,
    required this.tableName,
    this.fields = const <ModelField>[],
    this.relations = const <ModelRelation>[],
  });

  /// Model class name (e.g. `'User'`).
  final String name;

  /// Snake-case plural table name backing this model.
  final String tableName;

  /// Typed fields the model declares.
  final List<ModelField> fields;

  /// Relation declarations the model exposes.
  final List<ModelRelation> relations;
}
