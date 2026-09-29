import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Where a Beak project sits in its pub workspace.
///
/// A Dart project resolves its packages into `.dart_tool/package_config.json`
/// beside the pubspec that runs `pub get`. In a pub workspace that is the
/// workspace root's pubspec, once for every member, so the agent docs and the
/// installed skills go there too: one copy per workspace, next to the file
/// that says which Beak version it resolved.
///
/// ```dart
/// final workspace = BeakWorkspace.locate(Directory('apps/admin'));
/// print(workspace.docsDirectory.path); // <workspace root>/.dart_tool/beak/docs
/// ```
final class BeakWorkspace {
  /// Creates a workspace for [projectRoot] rooted at [workspaceRoot].
  const BeakWorkspace({required this.projectRoot, required this.workspaceRoot});

  /// Finds the workspace of the project at [projectRoot].
  ///
  /// A pubspec with `resolution: workspace` belongs to the first ancestor
  /// whose `workspace:` list names it, by path or by a `*` glob. Anything
  /// else, including a pubspec that cannot be read, is its own workspace.
  /// [workspaceRoot] overrides the search: it is the answer when the caller
  /// already knows it, which `--root` is for.
  factory BeakWorkspace.locate(
    Directory projectRoot, {
    Directory? workspaceRoot,
  }) {
    if (workspaceRoot != null) {
      return BeakWorkspace(
        projectRoot: projectRoot,
        workspaceRoot: workspaceRoot,
      );
    }
    final YamlMap? pubspec = _pubspecIn(projectRoot);
    if (pubspec?['resolution'] == 'workspace') {
      for (
        Directory parent = projectRoot.parent;
        !p.equals(parent.path, parent.parent.path);
        parent = parent.parent
      ) {
        final String relative = p.posix.joinAll(
          p.split(p.relative(projectRoot.path, from: parent.path)),
        );
        if (_listsMember(_pubspecIn(parent), relative)) {
          return BeakWorkspace(projectRoot: projectRoot, workspaceRoot: parent);
        }
      }
    }
    return BeakWorkspace(projectRoot: projectRoot, workspaceRoot: projectRoot);
  }

  /// Where a bundle is materialized, relative to the workspace root.
  static const String docsPath = '.dart_tool/beak/docs';

  /// The project Beak's files are written for.
  final Directory projectRoot;

  /// The directory `pub get` resolves for, and where docs and skills go.
  final Directory workspaceRoot;

  /// Whether the project is a member of a workspace rooted elsewhere.
  bool get isWorkspaceMember => !p.equals(projectRoot.path, workspaceRoot.path);

  /// The resolution `pub get` wrote, whether or not it exists yet.
  File get packageConfigFile =>
      File(p.join(workspaceRoot.path, '.dart_tool', 'package_config.json'));

  /// Whether `pub get` has run.
  bool get hasPackageConfig => packageConfigFile.existsSync();

  /// The directory the docs bundle is materialized into.
  Directory get docsDirectory =>
      Directory(p.joinAll([workspaceRoot.path, ...docsPath.split('/')]));

  /// The project's path from the workspace root, with `/` separators, or `.`
  /// when it is the root.
  String get projectPathInWorkspace {
    final String relative = p.relative(
      projectRoot.path,
      from: workspaceRoot.path,
    );
    return p.posix.joinAll(p.split(relative));
  }

  /// The pubspec in [directory] as a mapping, or `null` when there is none
  /// or it is not one.
  static YamlMap? _pubspecIn(Directory directory) {
    final file = File(p.join(directory.path, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return null;
    }
    try {
      return switch (loadYaml(file.readAsStringSync())) {
        final YamlMap map => map,
        _ => null,
      };
    } on YamlException {
      return null;
    }
  }

  /// Whether [pubspec]'s `workspace:` list names the member at [relative].
  static bool _listsMember(YamlMap? pubspec, String relative) {
    if (pubspec?['workspace'] case final YamlList entries) {
      for (final entry in entries) {
        if (entry is String && _matches(entry, relative)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the workspace entry [pattern] names [relative].
  ///
  /// An entry is a path; `*` stands for one path segment.
  static bool _matches(String pattern, String relative) {
    final List<String> wanted = _segmentsOf(pattern);
    final List<String> actual = _segmentsOf(relative);
    if (wanted.length != actual.length) {
      return false;
    }
    for (var index = 0; index < wanted.length; index += 1) {
      final RegExp segment = RegExp(
        '^${wanted[index].split('*').map(RegExp.escape).join('[^/]*')}\$',
      );
      if (!segment.hasMatch(actual[index])) {
        return false;
      }
    }
    return true;
  }

  static List<String> _segmentsOf(String path) => [
    for (final segment in path.split('/'))
      if (segment.isNotEmpty && segment != '.') segment,
  ];
}
