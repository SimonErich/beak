@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'api_scenario.dart';

/// The whole API scenario on SQLite, with uploads on local disk.
///
/// No Docker, no services, seconds to run — so every pull request checks
/// restore, the row policy, uploads with variants, CSV export and the 409,
/// rather than only the machines that happen to have Postgres up.
/// `e2e/postgres_test.dart` runs the same assertions against the real thing.
void main() {
  final Directory uploads = Directory.systemTemp.createTempSync(
    'store_uploads_',
  );
  tearDownAll(() => uploads.deleteSync(recursive: true));

  runStoreApiScenario(
    description: 'store API on sqlite',
    environmentFor: (port) => {
      'DATABASE_URL': 'sqlite::memory:',
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      // Served by the Beak server itself, so an uploaded file's URL resolves
      // with nothing else running.
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
}
