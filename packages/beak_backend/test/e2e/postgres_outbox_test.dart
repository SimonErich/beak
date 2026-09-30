@Tags(['e2e'])
library;

import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// The Postgres endpoint under test, matching `docker-compose.yml`; override
/// via `DATABASE_URL`.
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
  late DatabaseAdapter admin;
  late DatabaseAdapter scratch;
  late String scratchName;

  setUpAll(() async {
    reachable = await postgresIsReachable();
    if (!reachable) return;
    admin = adapterFromUrl(databaseUrl);
    await admin.connect();
    scratchName = 'beak_outbox_e2e_${DateTime.now().microsecondsSinceEpoch}';
    await admin.rawQuery('CREATE DATABASE $scratchName', const []);
    scratch = adapterFromUrl(databaseUrl.replace(path: '/$scratchName'));
    await scratch.connect();
  });

  tearDownAll(() async {
    if (!reachable) return;
    await scratch.disconnect();
    await admin.rawQuery('DROP DATABASE IF EXISTS $scratchName', const []);
    await admin.disconnect();
  });

  test('the outbox stores millisecond timestamps, claims, delivers and prunes '
      'on Postgres', () async {
    if (!reachable) {
      markTestSkipped(
        'Postgres is unreachable at ${databaseUrl.host}:${databaseUrl.port}.',
      );
      return;
    }
    await const BeakOutboxMigration().up(scratch);
    await BeakOutbox.enqueue(
      scratch,
      key: 'order:1:email',
      kind: 'email',
      payload: BeakRecord.fromRow({'amount': 100}),
    );
    final delivered = <String>[];
    final worker = BeakOutboxWorker(
      adapter: scratch,
      handlers: {'email': (effect) async => delivered.add(effect.key)},
    );

    expect(await worker.drain(), 1);
    expect(delivered, ['order:1:email']);
    final row = (await scratch.select(
      const QueryDescriptor(table: BeakOutboxMigration.table),
    )).single;
    expect(row['status'], 'delivered');
    expect(
      row['available_at'],
      greaterThan(DateTime.utc(2026).millisecondsSinceEpoch),
    );

    expect(
      await BeakOutbox.prune(
        scratch,
        olderThan: Duration.zero,
        now: () => DateTime.now().add(const Duration(days: 1)),
      ),
      1,
    );
  });

  test(
    'competing workers on Postgres never claim the same effect twice',
    () async {
      if (!reachable) {
        markTestSkipped(
          'Postgres is unreachable at ${databaseUrl.host}:${databaseUrl.port}.',
        );
        return;
      }
      await scratch.rawQuery(
        'DELETE FROM ${BeakOutboxMigration.table}',
        const [],
      );
      for (var i = 0; i < 30; i += 1) {
        await BeakOutbox.enqueue(
          scratch,
          key: 'race:$i',
          kind: 'email',
          payload: BeakRecord.fromRow({'i': i}),
        );
      }
      final calls = <String, int>{};
      Future<void> deliver(BeakOutboxEffect effect) async {
        calls.update(effect.key, (count) => count + 1, ifAbsent: () => 1);
      }

      final workers = [
        for (var i = 0; i < 3; i += 1)
          BeakOutboxWorker(adapter: scratch, handlers: {'email': deliver}),
      ];
      final delivered = await Future.wait([
        for (final worker in workers) worker.drain(),
      ]);

      expect(delivered.reduce((a, b) => a + b), 30);
      expect(calls, hasLength(30));
      expect(calls.values.toSet(), {1});
    },
  );
}
