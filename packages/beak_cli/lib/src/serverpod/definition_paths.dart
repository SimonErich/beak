import 'dart:io';

import 'package:path/path.dart' as p;

/// The package name in [pubspec], or the folder name when it declares none.
String definitionPackageName(File pubspec) =>
    RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1) ??
    p.basename(p.dirname(pubspec.path));

/// The snake_case file stem of a definition class name.
String definitionFileStem(String name) => name
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

/// The generated part path under the definitions package's `lib/`.
String definitionPartPath({required String area, required String name}) =>
    'src/generated/models/$area/${definitionFileStem(name)}.beak.dart';

/// The `part` URI from a class library to its generated part.
String definitionPartUri({
  required String area,
  required String name,
  required String library,
}) => p.posix.relative(
  definitionPartPath(area: area, name: name),
  from: p.posix.dirname(library),
);
