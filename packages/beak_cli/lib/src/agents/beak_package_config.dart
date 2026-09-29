import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One Beak package `pub get` resolved.
final class BeakResolvedPackage {
  /// Creates a resolved package.
  const BeakResolvedPackage({
    required this.name,
    required this.root,
    this.version,
  });

  /// The package name: `beak`, or `beak_` and a suffix.
  final String name;

  /// The directory holding the package's `pubspec.yaml`, `lib/` and, for the
  /// packages that ship them, `doc/` and `skills/`. It is in the pub cache
  /// for a hosted or git dependency, and in the checkout for a path one.
  final Directory root;

  /// The `version:` of the package's pubspec, or `null` when it declares none
  /// or the pubspec cannot be read.
  final String? version;
}

/// The Beak packages a project resolved, read from `package_config.json`.
///
/// `pub get` records where each package lives, whatever kind of dependency it
/// is: a path checkout, the hosted cache, a git cache, and on Windows a
/// drive path. Reading that file is how the CLI finds the docs and skills
/// that ship with the exact Beak version the project uses.
///
/// ```dart
/// final config = BeakPackageConfig.read(workspace.packageConfigFile);
/// print(config?.core?.version); // 0.9.0
/// ```
final class BeakPackageConfig {
  /// Creates a config over [packages], keyed by package name.
  const BeakPackageConfig(this.packages);

  /// Reads [file], keeping the `beak` and `beak_*` packages.
  ///
  /// Returns `null` when the file is missing or is not a package config: a
  /// project that has not run `pub get` is not an error for the caller.
  static BeakPackageConfig? read(File file) {
    if (!file.existsSync()) {
      return null;
    }
    final Object? document;
    try {
      document = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return null;
    }
    if (document is! Map<String, Object?>) {
      return null;
    }
    final Object? entries = document['packages'];
    if (entries is! List<Object?>) {
      return null;
    }
    final base = file.absolute.parent.uri;
    final packages = <String, BeakResolvedPackage>{};
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final Object? name = entry['name'];
      final Object? rootUri = entry['rootUri'];
      if (name is! String ||
          rootUri is! String ||
          !(name == 'beak' || name.startsWith('beak_'))) {
        continue;
      }
      final String? path = rootPathOf(rootUri, base: base);
      if (path == null) {
        continue;
      }
      final root = Directory(path);
      packages[name] = BeakResolvedPackage(
        name: name,
        root: root,
        version: _versionOf(root),
      );
    }
    return BeakPackageConfig(packages);
  }

  /// The resolved `beak` and `beak_*` packages, by name.
  final Map<String, BeakResolvedPackage> packages;

  /// `beak_core`, the package that carries the docs bundle, when resolved.
  BeakResolvedPackage? get core => packages['beak_core'];

  /// The `beak` umbrella package, when resolved.
  BeakResolvedPackage? get umbrella => packages['beak'];

  /// The directory a `rootUri` of `package_config.json` names, or `null`
  /// when it is not a file location.
  ///
  /// [base] is the URI of the directory holding the file: a relative
  /// reference is relative to it, and `../..` from `.dart_tool/` is the
  /// project. [windows] chooses drive-path output and defaults to the
  /// platform; it is a parameter so the Windows form is testable anywhere.
  static String? rootPathOf(
    String rootUri, {
    required Uri base,
    bool? windows,
  }) {
    final Uri resolved = base.resolve(rootUri);
    if (resolved.scheme != 'file') {
      return null;
    }
    final String path = resolved.toFilePath(
      windows: windows ?? Platform.isWindows,
    );
    final String separator = (windows ?? Platform.isWindows) ? r'\' : '/';
    return path.length > 1 && path.endsWith(separator)
        ? path.substring(0, path.length - 1)
        : path;
  }

  static String? _versionOf(Directory root) {
    final file = File(p.join(root.path, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return null;
    }
    try {
      if (loadYaml(file.readAsStringSync()) case final YamlMap pubspec) {
        return switch (pubspec['version']) {
          final String version => version,
          _ => null,
        };
      }
    } on YamlException {
      return null;
    }
    return null;
  }
}
