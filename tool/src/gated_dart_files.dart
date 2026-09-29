/// The Dart files the repository guards scan.
///
/// `tool/check_no_material.dart` and `tool/check_hook_widgets.dart` gate the
/// same code: every package under `packages/` and `examples/` except the
/// vendored `worm*` ones, and, in a pub workspace root such as
/// `examples/serverpod`, only the members that depend on a Beak package (the
/// rest is a Serverpod template, not Beak code).
library;

import 'dart:io';

/// Directories that hold gated packages, relative to the repo root.
const List<String> packageRootDirs = ['packages', 'examples'];

/// Whether [pubspecSource] is a pub workspace root (a `workspace:` list).
///
/// `examples/serverpod` is one. Its Serverpod template members (the
/// storefront app) are not Beak code, so only its Beak members are gated.
bool isWorkspaceRoot(String pubspecSource) =>
    RegExp(r'^workspace:', multiLine: true).hasMatch(pubspecSource);

/// Whether [pubspecSource] depends on a Beak package.
bool dependsOnBeak(String pubspecSource) =>
    RegExp(r'^  beak[a-z_]*:', multiLine: true).hasMatch(pubspecSource);

/// All Dart files of the gated packages under [repoRoot], skipping hidden
/// directories (such as `.dart_tool`) and build output.
///
/// With [subdirectory], only the files under that directory of each package
/// (`lib`, say), so tests and tools are left alone.
Iterable<File> gatedDartFiles({
  String repoRoot = '.',
  String? subdirectory,
}) sync* {
  String below(String path) => repoRoot == '.' ? path : '$repoRoot/$path';
  for (final rootDir in packageRootDirs) {
    final root = Directory(below(rootDir));
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
        yield* _beakMemberDartFiles(entity, subdirectory);
        continue;
      }
      yield* _dartFilesUnder(_within(entity, subdirectory));
    }
  }
}

Directory _within(Directory package, String? subdirectory) =>
    subdirectory == null ? package : Directory('${package.path}/$subdirectory');

Iterable<File> _beakMemberDartFiles(
  Directory workspace,
  String? subdirectory,
) sync* {
  for (final entity in workspace.listSync(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final pubspec = File('${entity.path}/pubspec.yaml');
    if (pubspec.existsSync() && dependsOnBeak(pubspec.readAsStringSync())) {
      yield* _dartFilesUnder(_within(entity, subdirectory));
    }
  }
}

Iterable<File> _dartFilesUnder(Directory dir) sync* {
  if (!dir.existsSync()) {
    return;
  }
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
