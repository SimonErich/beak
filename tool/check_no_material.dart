/// Material/Cupertino import guard (`melos run guard-material`).
///
/// Beak UI is built exclusively with obers_ui: importing
/// `package:flutter/material.dart` or `package:flutter/cupertino.dart` is a
/// blocking defect. This tool scans every Dart file of the gated packages
/// (under `packages/` and `examples/`, vendored `worm*` excluded) and exits
/// non-zero listing each offending file.
library;

import 'dart:io';

import 'src/gated_dart_files.dart';

export 'src/gated_dart_files.dart' show dependsOnBeak, isWorkspaceRoot;

/// Import URIs that must never appear in Beak code.
const List<String> forbiddenImportUris = [
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
];

/// Returns each forbidden URI referenced by an `import` or `export`
/// directive in [dartSource], once per offending directive.
List<String> forbiddenImportsIn(String dartSource) {
  final violations = <String>[];
  for (final line in dartSource.split('\n')) {
    final trimmed = line.trim();
    final isDirective =
        trimmed.startsWith('import ') || trimmed.startsWith('export ');
    if (!isDirective) {
      continue;
    }
    for (final uri in forbiddenImportUris) {
      if (trimmed.contains("'$uri'") || trimmed.contains('"$uri"')) {
        violations.add(uri);
      }
    }
  }
  return violations;
}

void main() {
  final violations = <String>[];
  var scannedFileCount = 0;
  for (final file in gatedDartFiles()) {
    scannedFileCount += 1;
    for (final uri in forbiddenImportsIn(file.readAsStringSync())) {
      violations.add('${file.path}: $uri');
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln('Forbidden Material/Cupertino imports found:');
    violations.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Material-import guard passed ($scannedFileCount Dart files scanned).',
  );
}
