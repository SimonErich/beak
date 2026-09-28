/// The Shelf server half of Beak: the host, its configuration, storage
/// wiring, auth and policy.
///
/// The generated host in `lib/beak/server.g.dart` imports this, and so does
/// `lib/server.dart` when a project overrides middleware or policy. It
/// reaches `dart:io` and a database driver, so a panel file must never
/// import it — the web-safety guard fails the build if one does.
///
/// Re-exports `package:beak/beak.dart`, so a `lib/server.dart` writing a row
/// policy has the columns and filters it scopes with under one import.
///
/// `beak prepare` writes the host and a `bin/serve.dart` that starts it, so a
/// project's entrypoint names neither this library nor a single resource:
///
/// ```dart
/// import 'dart:io';
///
/// import 'package:shop/beak/server.g.dart';
///
/// Future<void> main() async {
///   final HttpServer server = await beakHost().serve();
///   stderr.writeln(
///     'listening on http://${server.address.host}:${server.port}',
///   );
/// }
/// ```
library;

export 'beak.dart';
export 'package:beak_backend/beak_backend.dart';
export 'package:beak_core/io.dart';
