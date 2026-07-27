import 'dart:io';

import 'package:superdashboard/server/server_builder.dart';

/// Serves the superdashboard API.
///
/// `BeakServeHost` reads `.env`, connects worm to Postgres, resolves the
/// storage driver, and assembles the generated API for all 49 models — so
/// this file only has to say which host to serve.
Future<void> main() async {
  final HttpServer server = await demoHost().serve();
  stderr.writeln(
    'superdashboard listening on '
    'http://${server.address.host}:${server.port}',
  );
}
