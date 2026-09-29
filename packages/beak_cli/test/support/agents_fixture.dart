/// A throwaway Beak project with a resolved `beak_core` docs bundle.
///
/// The agent files depend on three things outside the project: the pub
/// resolution, the docs bundle in `beak_core`, and skills shipped by Beak
/// packages. This builds all three under a temp directory so the commands
/// that read them run without `pub get` or a network.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temp workspace holding a project (`app/`) and the packages it resolves
/// (`pkgs/`).
final class AgentsFixture {
  /// Creates the directories and registers their removal after the test.
  AgentsFixture() : tmp = Directory.systemTemp.createTempSync('beak_agents_') {
    addTearDown(() => tmp.deleteSync(recursive: true));
    project.createSync(recursive: true);
  }

  /// The root of everything the fixture writes.
  final Directory tmp;

  /// The Beak project.
  Directory get project => Directory(p.join(tmp.path, 'app'));

  /// Where the packages the project resolves live.
  Directory package(String name) => Directory(p.join(tmp.path, 'pkgs', name));

  /// The real block templates, by file stem.
  static Map<String, String> realTemplates() => {
    for (final name in const [
      'standalone',
      'embedded',
      'serverpod-admin',
      'workspace-root',
    ])
      name: File('../../docs/_agents/blocks/$name.md').readAsStringSync(),
  };

  /// Writes the project's pubspec, and `beak.yaml` when [beakYaml] is given.
  void writeProject({
    List<String> dependencies = const ['beak'],
    String name = 'app',
    String? beakYaml,
    bool member = false,
  }) {
    write(
      'app/pubspec.yaml',
      'name: $name\n'
          '${member ? 'resolution: workspace\n' : ''}'
          'dependencies:\n${[for (final d in dependencies) '  $d: any\n'].join()}',
    );
    if (beakYaml != null) {
      write('app/beak.yaml', beakYaml);
    }
  }

  /// Writes `beak_core` with a docs bundle at [version].
  ///
  /// [templates] are the block templates it ships (the real ones by
  /// default; pass an empty map for a bundle without any).
  void writeBundle({
    String version = '0.9.0',
    Map<String, String>? templates,
    Map<String, String> pages = const {
      'ai-index.md': '# Index\n',
      'models/defining-models.md': '# Models\n',
    },
  }) {
    final Map<String, String> files = {
      ...pages,
      for (final template in (templates ?? realTemplates()).entries)
        '_agents/blocks/${template.key}.md': template.value,
    };
    final docs = Directory(
      p.join(package('beak_core').path, 'doc', 'agent-docs'),
    );
    if (docs.existsSync()) {
      docs.deleteSync(recursive: true);
    }
    for (final file in files.entries) {
      write('pkgs/beak_core/doc/agent-docs/${file.key}', file.value);
    }
    write(
      'pkgs/beak_core/doc/agent-docs/manifest.json',
      jsonEncode({
        'format': 1,
        'beak': version,
        'index': 'ai-index.md',
        'pages': pages.length,
        'files': {
          for (final file in files.entries)
            file.key: sha256.convert(utf8.encode(file.value)).toString(),
        },
      }),
    );
    write(
      'pkgs/beak_core/pubspec.yaml',
      'name: beak_core\nversion: $version\n',
    );
  }

  /// Ships the skill [name] from [packageName], at [version].
  void writeSkill(
    String packageName,
    String name, {
    String version = '0.9.0',
    String body = 'Do the thing.\n',
  }) {
    write(
      'pkgs/$packageName/pubspec.yaml',
      'name: $packageName\nversion: $version\n',
    );
    write(
      'pkgs/$packageName/skills/$name/SKILL.md',
      '---\nname: $name\ndescription: A skill.\n---\n$body',
    );
  }

  /// Writes the resolution `pub get` would, listing [packages] and, in a
  /// workspace, at [workspaceRoot] (default: the project itself).
  void resolve(List<String> packages, {String workspaceRoot = 'app'}) {
    write(
      '$workspaceRoot/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final name in packages)
            {'name': name, 'rootUri': package(name).uri.toString()},
        ],
      }),
    );
  }

  /// Writes [content] to [path] under [tmp].
  File write(String path, String content) => File(p.join(tmp.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  /// The text of [path] under the project.
  String read(String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  /// Whether [path] exists under the project, as a file or a folder.
  bool exists(String path) =>
      FileSystemEntity.typeSync(p.join(project.path, path)) !=
      FileSystemEntityType.notFound;
}
