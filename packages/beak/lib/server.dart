/// The Shelf server half of Beak: the host, its configuration, storage
/// wiring, auth and policy.
///
/// Import this from `bin/serve.dart` and from `lib/server.dart` when a
/// project overrides middleware or policy. It reaches `dart:io` and a
/// database driver, so a panel file must never import it — the web-safety
/// guard fails the build if one does.
///
/// Re-exports `package:beak/beak.dart`, so a `lib/server.dart` writing a row
/// policy has the columns and filters it scopes with under one import.
///
/// ```dart
/// import 'package:beak/server.dart';
///
/// Future<void> main(List<String> args) => beakHost().serve();
/// ```
library;

export 'beak.dart';
export 'package:beak_backend/beak_backend.dart';
export 'package:beak_core/io.dart';
