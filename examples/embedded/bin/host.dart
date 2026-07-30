import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:embedded/beak/server.g.dart';
import 'package:embedded/legacy_system.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// The host application's server, with Beak mounted inside it.
///
/// This is the point of this example: `BeakServer.handler` is an ordinary
/// Shelf handler, so an app that already has a server keeps it. Beak's API
/// lands under `/admin`, behind the host's own middleware and its own API-key
/// check — Beak never sees an unauthenticated request, and the host's routes
/// are untouched.
Future<void> main() async {
  final host = beakHost();
  await initializeWormPostgres(host.config);
  final DatabaseAdapter adapter = Worm.adapter();

  // The other system's table, created the way that system would create it.
  await LegacySystem.ensureSchema(adapter);
  await LegacySystem.seed(adapter);
  await MigrationRunner(
    adapter: adapter,
    migrations: host.migrations.toList(),
  ).migrate();

  final beak = host.buildServer(
    adapter: adapter,
    storage: host.resolveStorageDriver(),
  );

  final router = Router()
    ..get('/', (Request request) => Response.ok('the host application'))
    ..mount('/admin', beak.handler);

  final handler = const Pipeline()
      .addMiddleware(_requireApiKey)
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, '127.0.0.1', 8080);
  stderr.writeln(
    'host on http://${server.address.host}:${server.port} '
    '(Beak under /admin)',
  );
}

/// The host's own gate, in front of everything including Beak.
///
/// Beak has its own auth and its own policy; this shows that neither has to
/// be used. A request the host rejects never reaches the panel's API.
Handler Function(Handler) get _requireApiKey =>
    (Handler inner) =>
        (Request request) async =>
            request.headers['x-api-key'] ==
                const String.fromEnvironment(
                  'HOST_API_KEY',
                  defaultValue: 'let-me-in',
                )
            ? inner(request)
            : Response.forbidden('missing or wrong x-api-key');
