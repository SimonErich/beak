/// What an operator sees when the process cannot start: one line that names
/// the setting to fix, a distinct exit code, and (for a server that would
/// start but is wide open) one warning.
library;

import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Denies everything, so the server is not "allow all".
final class _DenyAllPolicy extends BeakAllowAllPolicy {
  const _DenyAllPolicy();

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) => false;
}

/// Adopts the fixture tables and can never be undone.
final class _AdoptNotes extends BeakBaselineMigration {
  const _AdoptNotes();

  @override
  String get name => '20260101_000000_adopt_notes';

  @override
  List<BeakModel> get models => const [NoteModel()];
}

Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

BeakServer _server({
  required String host,
  required int port,
  BeakPolicy policy = const BeakAllowAllPolicy(),
  Handler? router,
  void Function(String message)? onWarning,
}) {
  final registry = createApiRegistry();
  return BeakServer(
    config: BeakBackendConfig(
      databaseUrl: Uri.parse('sqlite::memory:'),
      port: port,
      host: host,
    ),
    registry: registry,
    dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
    policy: policy,
    router: router,
    onRequest: (entry) {},
    onWarning: onWarning,
  );
}

void main() {
  tearDown(Worm.reset);

  group('the wide-open warning', () {
    test(
      'a non-loopback host that allows everyone is warned about once',
      () async {
        final warnings = <String>[];
        final server = _server(
          host: '0.0.0.0',
          port: await _freePort(),
          onWarning: warnings.add,
        );

        final http = await server.start();
        addTearDown(() => http.close(force: true));

        expect(warnings, hasLength(1));
        expect(warnings.single, contains('BeakAllowAllPolicy'));
        expect(warnings.single, contains('0.0.0.0:${http.port}'));
        expect(warnings.single, isNot(contains('\n')));
      },
    );

    test('names the origin wildcard when CORS admits any origin', () async {
      final warnings = <String>[];
      final server = _server(
        host: '0.0.0.0',
        port: await _freePort(),
        onWarning: warnings.add,
      );

      final http = await server.start();
      addTearDown(() => http.close(force: true));

      expect(warnings.single, contains('CORS'));
    });

    test('a loopback host is not warned about', () async {
      final warnings = <String>[];
      final server = _server(
        host: '127.0.0.1',
        port: await _freePort(),
        onWarning: warnings.add,
      );

      final http = await server.start();
      addTearDown(() => http.close(force: true));

      expect(warnings, isEmpty);
    });

    test('a real policy is not warned about', () async {
      final warnings = <String>[];
      final server = _server(
        host: '0.0.0.0',
        port: await _freePort(),
        policy: const _DenyAllPolicy(),
        onWarning: warnings.add,
      );

      final http = await server.start();
      addTearDown(() => http.close(force: true));

      expect(warnings, isEmpty);
    });

    test('a replaced router has no policy to warn about', () async {
      final warnings = <String>[];
      final server = _server(
        host: '0.0.0.0',
        port: await _freePort(),
        router: (request) => Response.ok('{}'),
        onWarning: warnings.add,
      );

      final http = await server.start();
      addTearDown(() => http.close(force: true));

      expect(warnings, isEmpty);
    });
  });

  group('a port that is taken', () {
    test('names PORT instead of throwing a raw socket error', () async {
      final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(taken.close);
      final server = _server(host: '127.0.0.1', port: taken.port);

      await expectLater(
        server.start(),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            allOf(contains('${taken.port}'), contains('PORT')),
          ),
        ),
      );
    });
  });

  group('an address that cannot be bound', () {
    test('names HOST and PORT and carries the reason', () async {
      // TEST-NET-3 (RFC 5737): never assigned to a local interface.
      final server = _server(host: '203.0.113.1', port: await _freePort());

      await expectLater(
        server.start(),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            allOf(contains('203.0.113.1'), contains('HOST'), contains('PORT')),
          ),
        ),
      );
    });
  });

  group('runCli', () {
    test(
      'reports a bad DATABASE_URL on one line with the config code',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final host = BeakServeHost(
          registry: createApiRegistry(),
          environment: const {'DATABASE_URL': 'mysql://x/y'},
        );

        final code = await host.runCli(['migrate'], out: out, err: err);

        expect(code, BeakServeHost.configurationExitCode);
        expect(err.toString().trim().split('\n'), hasLength(1));
        expect(err.toString(), startsWith('error: '));
        expect(err.toString(), contains('DATABASE_URL'));
      },
    );

    test('reports a rollback of a baseline on one line', () async {
      final directory = await Directory.systemTemp.createTemp('beak_cli_');
      addTearDown(() => directory.delete(recursive: true));
      final host = BeakServeHost(
        registry: createApiRegistry(),
        migrations: const [_AdoptNotes()],
        environment: {'DATABASE_URL': 'sqlite:${directory.path}/beak.db'},
      );
      expect(await host.runCli(['migrate'], out: StringBuffer()), 0);
      final err = StringBuffer();

      final code = await host.runCli(
        ['migrate:rollback'],
        out: StringBuffer(),
        err: err,
      );

      expect(code, isNot(0));
      expect(err.toString().trim().split('\n'), hasLength(1));
      expect(err.toString(), contains('cannot be rolled back'));
    });
  });
}
