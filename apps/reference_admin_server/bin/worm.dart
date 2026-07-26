import 'dart:io';

import 'package:reference_admin_server/reference_admin_server.dart';

/// The project-aware worm CLI, over the same host the server uses — so the
/// schema and the API can never be wired from different registries.
///
/// Run e.g. `dart run bin/worm.dart migrate` or
/// `dart run bin/worm.dart db:seed`.
Future<void> main(List<String> args) async =>
    exit(await referenceHost().runCli(args));
