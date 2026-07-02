import 'dart:io';

import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/cli/cli_context.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/seeder/environment.dart';
import 'package:worm/src/seeder/seeder_base.dart';

/// One shared in-memory adapter so the test can re-introspect state
/// after CLI commands ran.
class TestHarness {
  TestHarness({
    Environment environment = Environment.development,
    DateTime? fixedNow,
    List<Migration> migrations = const <Migration>[],
    List<Seeder> seeders = const <Seeder>[],
    List<ModelInfo> models = const <ModelInfo>[],
  }) : projectRoot = Directory.systemTemp.createTempSync('worm_cli_test_'),
       _migrations = migrations,
       _seeders = seeders,
       _models = models,
       _environment = environment,
       _now = fixedNow ?? DateTime.utc(2026, 1, 2, 3, 4, 5);

  final Directory projectRoot;
  final Environment _environment;
  final DateTime _now;
  final List<Migration> _migrations;
  final List<Seeder> _seeders;
  final List<ModelInfo> _models;
  final StringBuffer out = StringBuffer();
  final StringBuffer err = StringBuffer();
  final InMemoryAdapter adapter = InMemoryAdapter();
  bool _connected = false;

  CliContext build() => CliContext(
    out: out,
    err: err,
    projectRoot: projectRoot,
    environment: _environment,
    now: () => _now,
    adapterFactory: _factory,
    migrations: _migrations,
    seeders: _seeders,
    models: _models,
  );

  Future<DatabaseAdapter> _factory() async {
    if (!_connected) {
      await adapter.connect();
      _connected = true;
    }
    return adapter;
  }

  void dispose() {
    if (projectRoot.existsSync()) {
      projectRoot.deleteSync(recursive: true);
    }
  }
}
