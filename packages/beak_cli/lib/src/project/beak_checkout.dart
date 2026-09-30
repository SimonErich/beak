import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Resolves the `--beak-path` of `beak create` and `beak init` to the
/// absolute, normalised repo root of a local Beak checkout.
///
/// [typed] is relative to [base], the directory the command runs in. A
/// generated pubspec sits one level below (`create`) or beside (`init`) where
/// the path was typed and is read from elsewhere by tools, so only an
/// absolute path names the same checkout everywhere.
///
/// Throws a [UsageException] carrying [usage] when `packages/beak` is missing
/// under the result, which is what naming the package instead of the repo root
/// (`beak/packages/beak`) looks like.
String resolveBeakCheckout(
  Directory base,
  String typed, {
  required String usage,
}) {
  final String root = p.normalize(p.join(base.absolute.path, typed));
  final String package = p.join(root, 'packages', 'beak');
  if (!Directory(package).existsSync()) {
    throw UsageException(
      '--beak-path must be the repo root of a Beak checkout: $package does '
      'not exist.',
      usage,
    );
  }
  return root;
}
