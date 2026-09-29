import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'beak_package_config.dart';
import 'beak_workspace.dart';

/// A folder of the workspace root that coding agents read skills from.
enum BeakSkillTarget {
  /// Claude Code: `.claude/skills`.
  claude('claude', '.claude'),

  /// The shared agent convention: `.agents/skills`.
  agents('agents', '.agents'),

  /// Cursor: `.cursor/skills`.
  cursor('cursor', '.cursor');

  const BeakSkillTarget(this.label, this.directoryName);

  /// The name used in `beak.yaml` and on the command line.
  final String label;

  /// The folder at the workspace root.
  final String directoryName;

  /// The target called [label], or `null` when there is none.
  static BeakSkillTarget? parse(String label) {
    for (final target in values) {
      if (target.label == label.trim()) {
        return target;
      }
    }
    return null;
  }

  /// The folder holding this target's skills, in [workspace].
  Directory skillsDirectory(BeakWorkspace workspace) =>
      Directory(p.join(workspace.workspaceRoot.path, directoryName, 'skills'));
}

/// The targets `beak agents` writes to when nobody says otherwise.
///
/// [configured] is `agents.skills` from `beak.yaml`: when it is set it wins,
/// and an empty list means never install skills. Without it, the folders the
/// workspace already has, and `.claude` with `.agents` when it has none.
List<BeakSkillTarget> defaultSkillTargets(
  BeakWorkspace workspace, {
  List<BeakSkillTarget>? configured,
}) {
  if (configured != null) {
    return configured;
  }
  final present = <BeakSkillTarget>[
    for (final target in BeakSkillTarget.values)
      if (Directory(
        p.join(workspace.workspaceRoot.path, target.directoryName),
      ).existsSync())
        target,
  ];
  return present.isEmpty
      ? const [BeakSkillTarget.claude, BeakSkillTarget.agents]
      : present;
}

/// A skill a resolved Beak package ships.
final class BeakShippedSkill {
  /// Creates a shipped skill.
  const BeakShippedSkill({
    required this.name,
    required this.package,
    required this.version,
    required this.source,
    required this.sha256,
  });

  /// The skill's name, which is also its folder name.
  final String name;

  /// The package that ships it.
  final String package;

  /// That package's version, if it declares one.
  final String? version;

  /// The skill's folder in the package.
  final Directory source;

  /// Hash of the skill's files.
  final String sha256;
}

/// What happened to one skill in one target.
enum BeakSkillOutcome {
  /// Copied into a target that did not have it.
  installed,

  /// Replaced by the version the package ships now.
  updated,

  /// Already current.
  unchanged,

  /// Left alone because it was edited (or is not Beak's); `--force` replaces
  /// it.
  keptEdited,

  /// Left alone because the `skills` CLI manages it.
  ownedBySkillsCli,

  /// Deleted because no resolved package ships it any more (or on
  /// `--remove`).
  removed,
}

/// One skill's fate in one target.
final class BeakSkillChange {
  /// Creates a change.
  const BeakSkillChange({
    required this.target,
    required this.name,
    required this.outcome,
  });

  /// The target folder.
  final BeakSkillTarget target;

  /// The skill.
  final String name;

  /// What happened, or with a dry run, what would.
  final BeakSkillOutcome outcome;

  /// Whether the outcome changes what is on disk.
  bool get writes => switch (outcome) {
    BeakSkillOutcome.installed ||
    BeakSkillOutcome.updated ||
    BeakSkillOutcome.removed => true,
    _ => false,
  };
}

/// What installing (or removing) skills did.
final class BeakSkillReport {
  /// Creates a report.
  const BeakSkillReport(this.changes, this.warnings);

  /// One entry per skill and target.
  final List<BeakSkillChange> changes;

  /// Shipped skills that were skipped as invalid, and why.
  final List<String> warnings;

  /// Whether anything on disk changes.
  bool get writes => changes.any((change) => change.writes);

  /// How many skills [target] has after the run, counting the ones already
  /// there.
  int countIn(BeakSkillTarget target) => changes
      .where(
        (change) =>
            change.target == target &&
            change.outcome != BeakSkillOutcome.removed &&
            change.outcome != BeakSkillOutcome.ownedBySkillsCli,
      )
      .length;
}

/// Where a Beak-installed skill stands against what its package ships.
enum BeakInstalledSkillStatus {
  /// Identical to what the package ships.
  current,

  /// Unedited, but the package ships a newer version.
  outdated,

  /// Edited since it was installed.
  modified,

  /// Unedited, and no resolved package ships it any more.
  orphaned,
}

/// A skill Beak installed, found by its sidecar.
final class BeakInstalledSkill {
  /// Creates an installed skill.
  const BeakInstalledSkill({
    required this.target,
    required this.name,
    required this.package,
    required this.status,
  });

  /// Where it is installed.
  final BeakSkillTarget target;

  /// The skill.
  final String name;

  /// The package it came from.
  final String package;

  /// How it compares with what is shipped.
  final BeakInstalledSkillStatus status;
}

/// The sidecar file that marks a skill folder as installed by Beak.
const String beakSkillSidecar = '.beak-skill.json';

/// The `skills` shipped by the resolved Beak packages in [config].
///
/// A skill is `<package root>/skills/<name>/SKILL.md`. Its folder name must
/// be lower-case words joined by hyphens, start with the package name spelled
/// with hyphens, and equal the `name:` of its front matter. One that is not
/// is skipped, and [warnings] says why.
List<BeakShippedSkill> shippedSkills(
  BeakPackageConfig config, {
  List<String>? warnings,
}) {
  final skills = <BeakShippedSkill>[];
  for (final package in config.packages.values) {
    final skillsDirectory = Directory(p.join(package.root.path, 'skills'));
    if (!skillsDirectory.existsSync()) {
      continue;
    }
    final List<Directory> folders = [
      for (final entity in skillsDirectory.listSync(followLinks: false))
        if (entity is Directory) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (final folder in folders) {
      final String name = p.basename(folder.path);
      final String? problem = _problemWith(package, folder, name);
      if (problem != null) {
        warnings?.add('${package.name}: skills/$name skipped, $problem');
        continue;
      }
      skills.add(
        BeakShippedSkill(
          name: name,
          package: package.name,
          version: package.version,
          source: folder,
          sha256: _hashOf(folder),
        ),
      );
    }
  }
  return skills;
}

/// Why the skill [name] in [folder] cannot be installed, or `null`.
String? _problemWith(
  BeakResolvedPackage package,
  Directory folder,
  String name,
) {
  final prefix = package.name.replaceAll('_', '-');
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
    return 'its folder name is not lower-case words joined by hyphens';
  }
  if (name != prefix && !name.startsWith('$prefix-')) {
    return 'its name must start with "$prefix-"';
  }
  final skillFile = File(p.join(folder.path, 'SKILL.md'));
  if (!skillFile.existsSync()) {
    return 'it has no SKILL.md';
  }
  final String? declared = _frontMatterName(skillFile.readAsStringSync());
  if (declared != name) {
    return declared == null
        ? 'its SKILL.md front matter has no name'
        : 'its SKILL.md names it "$declared"';
  }
  return null;
}

/// The `name:` in the front matter of a `SKILL.md`, or `null`.
String? _frontMatterName(String source) {
  final List<String> lines = source.replaceAll('\r\n', '\n').split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return null;
  }
  for (final line in lines.skip(1)) {
    if (line.trim() == '---') {
      return null;
    }
    final match = RegExp(r'^name:\s*(.+?)\s*$').firstMatch(line);
    if (match != null) {
      return match[1]!.replaceAll(RegExp('^["\']|["\']\$'), '');
    }
  }
  return null;
}

/// Installs the skills shipped by [config]'s packages into [targets].
///
/// Each goes to `<workspace root>/<target>/skills/<name>/` as a whole folder
/// with a `.beak-skill.json` sidecar recording the package, its version and a
/// hash of the files. The sidecar is how a later run tells a skill Beak
/// wrote and nobody touched (which it replaces when the package ships a new
/// one) from a skill someone edited (which it leaves alone unless [force] is
/// set). Skills Beak installed that no resolved package ships any more are
/// removed under the same rule, and a skill the `skills` CLI manages, per
/// `.dart_skills/skills_config.json`, is never touched. With [dryRun] the
/// report says what would change and nothing is written.
BeakSkillReport installSkills({
  required BeakWorkspace workspace,
  required BeakPackageConfig config,
  required List<BeakSkillTarget> targets,
  bool force = false,
  bool dryRun = false,
}) {
  final warnings = <String>[];
  final List<BeakShippedSkill> shipped = shippedSkills(
    config,
    warnings: warnings,
  );
  final changes = <BeakSkillChange>[];
  for (final target in targets) {
    final Set<String> owned = _ownedBySkillsCli(workspace, target);
    final Directory skills = target.skillsDirectory(workspace);
    for (final skill in shipped) {
      final destination = Directory(p.join(skills.path, skill.name));
      BeakSkillChange change(BeakSkillOutcome outcome) =>
          BeakSkillChange(target: target, name: skill.name, outcome: outcome);
      if (owned.contains(skill.name)) {
        changes.add(change(BeakSkillOutcome.ownedBySkillsCli));
        continue;
      }
      if (!destination.existsSync()) {
        changes.add(change(BeakSkillOutcome.installed));
        if (!dryRun) {
          _write(skill, destination);
        }
        continue;
      }
      final _Sidecar? sidecar = _Sidecar.read(destination);
      final bool isUnedited =
          sidecar != null && sidecar.sha256 == _hashOf(destination);
      if (!isUnedited && !force) {
        changes.add(change(BeakSkillOutcome.keptEdited));
        continue;
      }
      if (isUnedited && sidecar.sha256 == skill.sha256) {
        changes.add(change(BeakSkillOutcome.unchanged));
        continue;
      }
      changes.add(change(BeakSkillOutcome.updated));
      if (!dryRun) {
        destination.deleteSync(recursive: true);
        _write(skill, destination);
      }
    }
    final Set<String> shippedNames = {for (final skill in shipped) skill.name};
    changes.addAll(
      _remove(
        target: target,
        skills: skills,
        owned: owned,
        keep: shippedNames,
        force: force,
        dryRun: dryRun,
      ),
    );
  }
  return BeakSkillReport(changes, warnings);
}

/// Removes every skill Beak installed in each of [targets] that nobody has
/// edited, and reports the edited ones it kept. With [force] the edited ones
/// go too.
BeakSkillReport uninstallSkills({
  required BeakWorkspace workspace,
  List<BeakSkillTarget> targets = BeakSkillTarget.values,
  bool force = false,
  bool dryRun = false,
}) {
  final changes = <BeakSkillChange>[];
  for (final target in targets) {
    changes.addAll(
      _remove(
        target: target,
        skills: target.skillsDirectory(workspace),
        owned: const {},
        keep: const {},
        force: force,
        dryRun: dryRun,
      ),
    );
  }
  return BeakSkillReport(changes, const []);
}

/// The Beak-installed skills in [workspace], compared with [config]'s.
///
/// [config] is `null` before `pub get`; nothing is then known to be shipped,
/// so no installed skill is called outdated or orphaned.
List<BeakInstalledSkill> installedSkills(
  BeakWorkspace workspace,
  BeakPackageConfig? config,
) {
  final Map<String, BeakShippedSkill>? shipped = config == null
      ? null
      : {for (final skill in shippedSkills(config)) skill.name: skill};
  final found = <BeakInstalledSkill>[];
  for (final target in BeakSkillTarget.values) {
    for (final folder in _installedFolders(target.skillsDirectory(workspace))) {
      final _Sidecar sidecar = _Sidecar.read(folder)!;
      final BeakShippedSkill? current = shipped?[p.basename(folder.path)];
      final BeakInstalledSkillStatus status;
      if (sidecar.sha256 != _hashOf(folder)) {
        status = BeakInstalledSkillStatus.modified;
      } else if (shipped == null) {
        status = BeakInstalledSkillStatus.current;
      } else if (current == null) {
        status = BeakInstalledSkillStatus.orphaned;
      } else {
        status = current.sha256 == sidecar.sha256
            ? BeakInstalledSkillStatus.current
            : BeakInstalledSkillStatus.outdated;
      }
      found.add(
        BeakInstalledSkill(
          target: target,
          name: p.basename(folder.path),
          package: sidecar.package,
          status: status,
        ),
      );
    }
  }
  return found;
}

/// The Beak-installed skill folders directly under [skills].
List<Directory> _installedFolders(Directory skills) {
  if (!skills.existsSync()) {
    return const [];
  }
  return [
    for (final entity in skills.listSync(followLinks: false))
      if (entity is Directory && _Sidecar.read(entity) != null) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

/// Deletes the Beak-installed skills under [skills] that are not in [keep].
List<BeakSkillChange> _remove({
  required BeakSkillTarget target,
  required Directory skills,
  required Set<String> owned,
  required Set<String> keep,
  required bool force,
  required bool dryRun,
}) {
  final changes = <BeakSkillChange>[];
  for (final folder in _installedFolders(skills)) {
    final String name = p.basename(folder.path);
    if (keep.contains(name) || owned.contains(name)) {
      continue;
    }
    final bool isUnedited = _Sidecar.read(folder)!.sha256 == _hashOf(folder);
    if (!isUnedited && !force) {
      changes.add(
        BeakSkillChange(
          target: target,
          name: name,
          outcome: BeakSkillOutcome.keptEdited,
        ),
      );
      continue;
    }
    changes.add(
      BeakSkillChange(
        target: target,
        name: name,
        outcome: BeakSkillOutcome.removed,
      ),
    );
    if (!dryRun) {
      folder.deleteSync(recursive: true);
    }
  }
  return changes;
}

/// The skills the `skills` CLI installed into [target], by name.
Set<String> _ownedBySkillsCli(BeakWorkspace workspace, BeakSkillTarget target) {
  final file = File(
    p.join(workspace.workspaceRoot.path, '.dart_skills', 'skills_config.json'),
  );
  if (!file.existsSync()) {
    return const {};
  }
  final Object? document;
  try {
    document = jsonDecode(file.readAsStringSync());
  } on FormatException {
    return const {};
  }
  final owned = <String>{};
  if (document case {
    'installations': final Map<String, Object?> installations,
  }) {
    if (installations[target.label] case final Map<String, Object?> packages) {
      for (final package in packages.values) {
        if (package case {'skills': final List<Object?> skills}) {
          for (final skill in skills) {
            if (skill case {'name': final String name}) {
              owned.add(name);
            }
          }
        }
      }
    }
  }
  return owned;
}

/// Copies [skill] into [destination] and writes its sidecar.
void _write(BeakShippedSkill skill, Directory destination) {
  for (final entity in skill.source.listSync(recursive: true)) {
    if (entity is File) {
      final String relative = p.relative(entity.path, from: skill.source.path);
      File(p.join(destination.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
  File(p.join(destination.path, beakSkillSidecar)).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'package': skill.package, 'version': skill.version, 'sha256': skill.sha256})}\n',
  );
}

/// A hash of every file in [folder] but the sidecar: path and bytes, in path
/// order, so it does not depend on the order the filesystem lists them.
String _hashOf(Directory folder) {
  final List<File> files = [
    for (final entity in folder.listSync(recursive: true, followLinks: false))
      if (entity is File && p.basename(entity.path) != beakSkillSidecar) entity,
  ];
  final Map<String, File> byPath = {
    for (final file in files)
      p.posix.joinAll(p.split(p.relative(file.path, from: folder.path))): file,
  };
  final builder = BytesBuilder();
  for (final path in byPath.keys.toList()..sort()) {
    builder
      ..add(utf8.encode(path))
      ..addByte(0)
      ..add(byPath[path]!.readAsBytesSync())
      ..addByte(0);
  }
  return sha256.convert(builder.takeBytes()).toString();
}

/// The `.beak-skill.json` of an installed skill.
final class _Sidecar {
  const _Sidecar(this.package, this.sha256);

  /// The sidecar in [folder], or `null` when there is none that reads.
  static _Sidecar? read(Directory folder) {
    final file = File(p.join(folder.path, beakSkillSidecar));
    if (!file.existsSync()) {
      return null;
    }
    try {
      if (jsonDecode(file.readAsStringSync()) case {
        'package': final String package,
        'sha256': final String sha256,
      }) {
        return _Sidecar(package, sha256);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  final String package;
  final String sha256;
}
