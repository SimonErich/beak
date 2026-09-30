/// `BeakServeHost.serve()` end to end: a real socket, a real SQLite adapter,
/// and the work the host does around the listener.
library;

import 'dart:convert';
import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Creates the endpoint fixture schema, like a project's first migration.
final class _CreateApiSchema extends Migration {
  _CreateApiSchema({this.onUp});

  final void Function()? onUp;

  @override
  String get name => '20260101_000000_create_api_schema';

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    onUp?.call();
    for (final table in apiSchema) {
      await adapter.executeSchema(
        SchemaDescriptor.createTable(
          table: table.table,
          columns: [
            for (final column in table.columns)
              SchemaColumn(
                name: column.name,
                type: column.type,
                isPrimaryKey: column.isPrimaryKey,
                nullable: !column.isPrimaryKey,
              ),
          ],
        ),
      );
    }
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {}
}

/// Seeds the one note the served database should answer with.
final class _NoteSeeder extends Seeder {
  const _NoteSeeder();

  @override
  String get name => 'NoteSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) => adapter.insert(
    const InsertDescriptor(
      table: 'notes',
      values: {'id': 'seeded', 'title': 'Seeded in process'},
    ),
  );
}

Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within 5 seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  tearDown(Worm.reset);

  Future<BeakServeHost> host({
    String databaseUrl = 'sqlite::memory:',
    List<Migration>? migrations,
    BeakServerCustomizer? configure,
  }) async => BeakServeHost(
    registry: createApiRegistry(),
    migrations:
        migrations ??
        [
          const BeakCommitReceiptsMigration(),
          const BeakOutboxMigration(),
          _CreateApiSchema(),
        ],
    seeders: const [_NoteSeeder()],
    configure: configure,
    environment: {
      'DATABASE_URL': databaseUrl,
      'HOST': '127.0.0.1',
      'PORT': '${await _freePort()}',
      'BEAK_STORAGE_DRIVER': 'none',
    },
  );

  Future<Map<String, Object?>> post(
    HttpServer server,
    String path,
    Object body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}$path'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200, reason: text);
      return switch (jsonDecode(text)) {
        final Map<String, Object?> map => map,
        final Object? other => throw StateError('expected an object: $other'),
      };
    } finally {
      client.close();
    }
  }

  group('an in-memory database', () {
    test('is migrated and seeded in the serving process', () async {
      // `beak migrate` runs in another process, whose `sqlite::memory:` is a
      // different database; without this the server would serve no tables.
      final server = await (await host()).serve();
      addTearDown(() => server.close(force: true));

      final page = await post(
        server,
        '/api/notes/query',
        const BeakQuerySpec(table: 'notes').toJson(),
      );

      expect(page['total'], 1);
      expect(jsonEncode(page), contains('Seeded in process'));
    });
  });

  group('a file database', () {
    test('is left to the migration CLI', () async {
      final directory = await Directory.systemTemp.createTemp('beak_serve_');
      addTearDown(() => directory.delete(recursive: true));
      var migrated = false;

      final server = await (await host(
        databaseUrl: 'sqlite:${directory.path}/beak.db',
        migrations: [_CreateApiSchema(onUp: () => migrated = true)],
      )).serve();
      addTearDown(() => server.close(force: true));

      expect(
        migrated,
        isFalse,
        reason:
            'a persistent database is migrated '
            'explicitly, never on boot',
      );
    });
  });

  group('the outbox schedule', () {
    test('drains while the server listens and stops when it closes', () async {
      final delivered = <String>[];
      final server = await (await host(
        configure: (defaults) => defaults.build(
          outbox: BeakOutboxSchedule(
            interval: const Duration(milliseconds: 10),
            handlers: {'email': (effect) async => delivered.add(effect.key)},
          ),
        ),
      )).serve();
      Future<void> enqueue(String key) => BeakOutbox.enqueue(
        Worm.adapter(),
        key: key,
        kind: 'email',
        payload: BeakRecord.fromRow({'to': 'ada@example.com'}),
      );

      await enqueue('while-serving');
      await _until(() => delivered.contains('while-serving'));
      await server.close();
      await enqueue('after-close');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        delivered,
        ['while-serving'],
        reason:
            'a closed host drains no '
            'more effects',
      );
    });

    test('the returned server still reports the listener', () async {
      final server = await (await host(
        configure: (defaults) =>
            defaults.build(outbox: const BeakOutboxSchedule(handlers: {})),
      )).serve();
      addTearDown(() => server.close(force: true));

      expect(server.address.address, '127.0.0.1');
      expect(server.port, greaterThan(0));
      server
        ..autoCompress = true
        ..idleTimeout = const Duration(seconds: 30)
        ..serverHeader = 'beak'
        ..sessionTimeout = 60;
      expect(server.autoCompress, isTrue);
      expect(server.idleTimeout, const Duration(seconds: 30));
      expect(server.serverHeader, 'beak');
      expect(server.defaultResponseHeaders, isNotNull);
      expect(server.connectionsInfo().total, 0);
    });

    test(
      'an invalid schedule fails the boot before the port is bound',
      () async {
        final configured = await host(
          configure: (defaults) => defaults.build(
            outbox: const BeakOutboxSchedule(
              interval: Duration.zero,
              handlers: {},
            ),
          ),
        );
        // Hold the port: a host that bound before validating would fail with
        // a SocketException, and would have served requests in between.
        final holder = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          configured.config.port,
        );
        addTearDown(holder.close);

        await expectLater(
          configured.serve(),
          throwsA(isA<BeakConfigurationException>()),
        );
      },
    );
  });
}
