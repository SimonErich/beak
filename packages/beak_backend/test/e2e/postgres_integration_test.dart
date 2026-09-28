@Tags(['e2e'])
library;

import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// The Postgres endpoint under test, matching `docker-compose.yml` /
/// `.env.example` defaults; override via `DATABASE_URL`.
final Uri databaseUrl = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

Future<bool> postgresIsReachable() async {
  try {
    final socket = await Socket.connect(
      databaseUrl.host,
      databaseUrl.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  late bool reachable;

  setUpAll(() async {
    reachable = await postgresIsReachable();
  });

  /// Skips the calling test with a clear message when Postgres is down; the
  /// phase gate runs with services up, so these tests then run for real.
  bool guarded() {
    if (!reachable) {
      markTestSkipped(
        'Postgres is unreachable at ${databaseUrl.host}:${databaseUrl.port} '
        '— start it with `melos run up`.',
      );
      return false;
    }
    return true;
  }

  group('initializeBeakDatabase', () {
    tearDown(() async {
      await Worm.reset();
    });

    test(
      'initializes worm on the configured database and round-trips SQL',
      () async {
        if (!guarded()) {
          return;
        }
        final config = BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': databaseUrl.toString()},
        );
        await initializeBeakDatabase(config);

        final rows = await Worm.adapter().rawQuery(
          'SELECT 1 AS probe',
          const [],
        );
        expect(rows, [
          {'probe': 1},
        ]);
      },
    );
  });
}
