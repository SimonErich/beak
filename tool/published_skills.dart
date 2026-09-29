/// Validation of the agent skills Beak packages publish
/// (`dart run tool/published_skills.dart`).
///
/// A package ships a workflow for coding agents as
/// `packages/<pkg>/skills/<name>/SKILL.md`, optionally with
/// `references/*.md` for detail. Agents load these into their context, so the
/// rules are strict and cheap to break by accident:
///
/// - the folder is named exactly like the `name` in the front matter;
/// - the name is `[a-z0-9-]+`, at most 64 characters, and starts with the
///   package name (underscores as hyphens) and a hyphen, so two packages can
///   never publish the same skill;
/// - the description is present and at most 1024 characters;
/// - the body is at most 150 lines, and anything longer moves to
///   `references/`;
/// - every `beak <command>` it tells an agent to run is a command
///   `createBeakRunner` registers;
/// - every docs page it names exists.
///
/// The docs pages are named as the project sees them, under
/// `.dart_tool/beak/docs/`, which is a copy of `docs/` plus the files the
/// bundle adds at its root (see `tool/build_agent_docs.dart`).
///
/// A repository without skills passes.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

/// The longest skill name the skill format allows.
const int maxSkillNameLength = 64;

/// The longest skill description the skill format allows.
const int maxSkillDescriptionLength = 1024;

/// The longest `SKILL.md` body; anything longer belongs in `references/`.
const int maxSkillBodyLines = 150;

/// The files the docs bundle has at its root that `docs/` does not.
const Set<String> bundleRootFiles = {
  'ai-index.md',
  'changelog.md',
  'SUMMARY.md',
  'llms.txt',
  'manifest.json',
};

/// One problem found in one skill file.
final class SkillProblem {
  /// Creates a problem at [path] (relative to the repo root).
  const SkillProblem(this.path, this.message);

  /// The file the problem is in.
  final String path;

  /// What is wrong, in the imperative.
  final String message;

  @override
  String toString() => '$path: $message';

  @override
  bool operator ==(Object other) =>
      other is SkillProblem && other.path == path && other.message == message;

  @override
  int get hashCode => Object.hash(path, message);
}

/// The problems in every skill published under [root]'s `packages/`.
List<SkillProblem> checkPublishedSkills(Directory root) {
  final List<_Skill> skills = _skillFilesIn(root);
  final Set<String>? commands = skills.isEmpty
      ? const {}
      : registeredCommands(root);
  return [for (final skill in skills) ..._checkSkill(root, skill, commands)];
}

/// A published `SKILL.md`, and the package and folder it sits in.
typedef _Skill = ({String package, String folder, File file});

/// Every `packages/*/skills/*/SKILL.md` under [root], in path order.
List<_Skill> _skillFilesIn(Directory root) {
  final skills = <_Skill>[];
  final packages = Directory('${root.path}/packages');
  if (!packages.existsSync()) {
    return skills;
  }
  for (final package in packages.listSync(followLinks: false)) {
    final container = Directory('${package.path}/skills');
    if (package is! Directory || !container.existsSync()) {
      continue;
    }
    for (final folder in container.listSync(followLinks: false)) {
      final file = File('${folder.path}/SKILL.md');
      if (folder is Directory && file.existsSync()) {
        skills.add((
          package: package.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
          folder: folder.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
          file: file,
        ));
      }
    }
  }
  return skills..sort((a, b) => a.file.path.compareTo(b.file.path));
}

/// The names of the commands `createBeakRunner` registers, or `null` when
/// its source cannot be read.
///
/// Read from source rather than by importing the CLI, so the tooling tests
/// do not depend on the CLI package. Each `..addCommand(SomeCommand(` in the
/// runner names a class, whose `String get name => '...'` is the command.
Set<String>? registeredCommands(Directory root) {
  final runner = File('${root.path}/packages/beak_cli/lib/src/cli_runner.dart');
  if (!runner.existsSync()) {
    return null;
  }
  final String source = runner.readAsStringSync();
  final RegExpMatch? declaration = RegExp(
    r'CommandRunner<\w+>\s+createBeakRunner\(',
  ).firstMatch(source);
  if (declaration == null) {
    return null;
  }
  // The declaration runs until the next line that starts at column 0.
  final String rest = source.substring(declaration.end);
  final int end = rest.indexOf(RegExp(r'\n(?=\S)'));
  final classes = [
    for (final match in RegExp(
      r'addCommand\(\s*(\w+)\(',
    ).allMatches(end == -1 ? rest : rest.substring(0, end)))
      match.group(1)!,
  ];
  final sources = [
    for (final entity in Directory(
      '${root.path}/packages/beak_cli/lib',
    ).listSync(recursive: true, followLinks: false))
      if (entity is File && entity.path.endsWith('.dart'))
        entity.readAsStringSync(),
  ];
  final commands = <String>{};
  for (final name in classes) {
    for (final text in sources) {
      final RegExpMatch? declaration = RegExp(
        'class\\s+$name\\b',
      ).firstMatch(text);
      if (declaration == null) {
        continue;
      }
      final RegExpMatch? command = RegExp(
        r'''String get name\s*=>\s*['"]([^'"$]+)['"]''',
      ).firstMatch(text.substring(declaration.end));
      if (command != null) {
        commands.add(command.group(1)!);
      }
    }
  }
  return commands;
}

/// The problems in one skill.
List<SkillProblem> _checkSkill(
  Directory root,
  _Skill skill,
  Set<String>? commands,
) {
  final String path = _relative(root, skill.file.path);
  final problems = <SkillProblem>[];
  void report(String message) => problems.add(SkillProblem(path, message));

  final String text = skill.file.readAsStringSync().replaceAll('\r\n', '\n');
  final List<String> lines = text.split('\n');
  final int close = lines.first == '---' ? lines.indexOf('---', 1) : -1;
  if (close == -1) {
    report('has no front matter (needs name and description)');
    return problems;
  }
  final Object? front = loadYaml(lines.sublist(1, close).join('\n'));
  final Object? name = front is YamlMap ? front['name'] : null;
  final Object? description = front is YamlMap ? front['description'] : null;

  if (name is! String || name.isEmpty) {
    report('front matter has no name');
  } else {
    final String prefix = '${skill.package.replaceAll('_', '-')}-';
    if (name != skill.folder) {
      report('the name "$name" differs from the folder "${skill.folder}"');
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
      report('the name "$name" must match [a-z0-9-]+');
    }
    if (name.length > maxSkillNameLength) {
      report('the name is ${name.length} characters, over $maxSkillNameLength');
    }
    if (!name.startsWith(prefix)) {
      report('the name "$name" must start with "$prefix" (the package name)');
    }
  }
  if (description is! String || description.trim().isEmpty) {
    report('front matter has no description');
  } else if (description.length > maxSkillDescriptionLength) {
    report(
      'the description is ${description.length} characters, over '
      '$maxSkillDescriptionLength',
    );
  }

  final List<String> body = lines.sublist(close + 1);
  while (body.isNotEmpty && body.last.trim().isEmpty) {
    body.removeLast();
  }
  final int bodyLines =
      body.length - body.takeWhile((l) => l.trim().isEmpty).length;
  if (bodyLines > maxSkillBodyLines) {
    report(
      'the body is $bodyLines lines, over $maxSkillBodyLines; move detail to '
      'references/',
    );
  }

  final references = [
    skill.file,
    for (final entity in Directory(
      '${skill.file.parent.path}/references',
    ).listSyncIfExists())
      if (entity is File && entity.path.endsWith('.md')) entity,
  ];
  for (final file in references) {
    problems.addAll(_checkMentions(root, file, commands));
  }
  return problems;
}

/// The problems in the `beak` commands and docs paths [file] mentions.
List<SkillProblem> _checkMentions(
  Directory root,
  File file,
  Set<String>? commands,
) {
  final String path = _relative(root, file.path);
  final problems = <SkillProblem>[];
  final String text = file.readAsStringSync().replaceAll('\r\n', '\n');
  final List<String> lines = text.split('\n');

  final spans = <String>[
    for (final match in RegExp('`([^`\n]+)`').allMatches(text))
      match[1]!.trim(),
  ];
  var fenced = false;
  for (final line in lines) {
    if (line.trimLeft().startsWith('```')) {
      fenced = !fenced;
    } else if (fenced) {
      spans.add(line.trim().replaceFirst(RegExp(r'^\$\s+'), ''));
    }
  }

  final mentioned = <String>{};
  final docsPaths = <String>{};
  for (final span in spans) {
    final RegExpMatch? command = RegExp(
      r'^beak\s+([a-z][\w:-]*)',
    ).firstMatch(span);
    if (command != null) {
      mentioned.add(command.group(1)!);
    }
    final RegExpMatch? docs = RegExp(
      r'^(\.dart_tool/beak/)?docs/([^\s#]+\.(?:md|json|txt))(?:#\S*)?$',
    ).firstMatch(span);
    if (docs != null) {
      final bool bundled = docs.group(1) != null;
      final String page = docs.group(2)!;
      final bool exists =
          File('${root.path}/docs/$page').existsSync() ||
          (bundled && bundleRootFiles.contains(page));
      if (!exists) {
        docsPaths.add(span);
      }
    }
  }
  if (mentioned.isNotEmpty && commands == null) {
    problems.add(
      SkillProblem(
        path,
        'mentions `beak` commands, but createBeakRunner cannot be read from '
        'packages/beak_cli/lib/src/cli_runner.dart',
      ),
    );
  } else {
    for (final command in mentioned.toList()..sort()) {
      if (!commands!.contains(command)) {
        problems.add(
          SkillProblem(
            path,
            'runs `beak $command`, which createBeakRunner does not register',
          ),
        );
      }
    }
  }
  for (final span in docsPaths.toList()..sort()) {
    problems.add(SkillProblem(path, 'names `$span`, which is not a docs page'));
  }
  return problems;
}

/// [path] relative to [root].
String _relative(Directory root, String path) => path
    .substring(root.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');

/// The entries of a directory that may not exist.
extension on Directory {
  /// The entries of this directory, or none when it does not exist.
  List<FileSystemEntity> listSyncIfExists() =>
      existsSync() ? listSync(followLinks: false) : const [];
}

void main() {
  final List<SkillProblem> problems = checkPublishedSkills(Directory.current);
  if (problems.isEmpty) {
    stdout.writeln('Published skills check passed.');
    return;
  }
  stderr.writeln('Published skills check failed:');
  for (final problem in problems) {
    stderr.writeln('  $problem');
  }
  exit(1);
}
