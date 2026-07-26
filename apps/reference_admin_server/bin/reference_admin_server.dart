import 'dart:io';

import 'package:reference_admin_server/reference_admin_server.dart';

/// Serves the reference admin API.
///
/// `BeakServeHost` reads `.env`, connects worm to Postgres, resolves the
/// storage driver, and assembles the generated API for every registered
/// model — so this file only has to say which host to serve.
Future<void> main() async {
  final HttpServer server = await referenceHost().serve();
  stderr.writeln(
    'reference_admin_server listening on '
    'http://${server.address.host}:${server.port}',
  );
}
