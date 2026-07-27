import 'dart:io';

import 'package:superdashboard/server/server_builder.dart';

/// The project-aware worm CLI, over the same host the server uses — so the
/// schema and the API can never be wired from different registries.
///
/// Run `dart run bin/worm.dart migrate` or `dart run bin/worm.dart db:seed`.
Future<void> main(List<String> args) async =>
    exit(await demoHost().runCli(args));
