/// Material/Cupertino import guard (`melos run guard-material`).
///
/// Beak UI is built exclusively with obers_ui: importing
/// `package:flutter/material.dart` or `package:flutter/cupertino.dart` is a
/// blocking defect. This tool scans every Dart file of the gated packages
/// (under `packages/` and `examples/`, vendored `worm*` excluded) and exits
/// non-zero listing each offending file.
library;

import 'dart:io';

/// Import URIs that must never appear in Beak code.
const List<String> forbiddenImportUris = [
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
];

/// Directories that hold gated packages, relative to the repo root.
const List<String> packageRootDirs = ['packages', 'examples'];

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
  for (final file in _gatedDartFiles()) {
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

/// All Dart files of the gated packages, skipping hidden directories (such
/// as `.dart_tool`) and build output.
Iterable<File> _gatedDartFiles() sync* {
  for (final rootDir in packageRootDirs) {
    final root = Directory(rootDir);
    if (!root.existsSync()) {
      continue;
    }
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (name.startsWith('worm')) {
        continue;
      }
      final pubspec = File('${entity.path}/pubspec.yaml');
      if (!pubspec.existsSync()) {
        continue;
      }
      if (isWorkspaceRoot(pubspec.readAsStringSync())) {
        yield* _beakMemberDartFiles(entity);
        continue;
      }
      yield* _dartFilesUnder(entity);
    }
  }
}

/// Whether [pubspecSource] is a pub workspace root (a `workspace:` list).
///
/// `examples/serverpod` is one. Its Serverpod template members (the
/// storefront app) are not Beak code, so only its Beak members are gated.
bool isWorkspaceRoot(String pubspecSource) =>
    RegExp(r'^workspace:', multiLine: true).hasMatch(pubspecSource);

/// Whether [pubspecSource] depends on a Beak package.
bool dependsOnBeak(String pubspecSource) =>
    RegExp(r'^  beak[a-z_]*:', multiLine: true).hasMatch(pubspecSource);

Iterable<File> _beakMemberDartFiles(Directory workspace) sync* {
  for (final entity in workspace.listSync(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final pubspec = File('${entity.path}/pubspec.yaml');
    if (pubspec.existsSync() && dependsOnBeak(pubspec.readAsStringSync())) {
      yield* _dartFilesUnder(entity);
    }
  }
}

Iterable<File> _dartFilesUnder(Directory dir) sync* {
  for (final entity in dir.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (entity is Directory) {
      if (name.startsWith('.') || name == 'build') {
        continue;
      }
      yield* _dartFilesUnder(entity);
    } else if (entity is File && name.endsWith('.dart')) {
      yield entity;
    }
  }
}
