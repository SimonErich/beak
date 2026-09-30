import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/beak_project_config.dart';
import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_reader.dart';
import '../version.dart';
import 'beak_block_renderer.dart';
import 'beak_claude_md.dart';
import 'beak_docs_bundle.dart';
import 'beak_managed_block.dart';
import 'beak_package_config.dart';
import 'beak_project_kind.dart';
import 'beak_skill_installer.dart';
import 'beak_workspace.dart';
import '../project/beak_authored_main.dart';

/// What `beak agents` was asked to do.
final class BeakAgentOptions {
  /// Creates options; the defaults are a plain `beak agents`.
  const BeakAgentOptions({
    this.instructions,
    this.docs,
    this.skills,
    this.installSkills = true,
    this.check = false,
    this.dryRun = false,
    this.force = false,
    this.remove = false,
    this.print = false,
    this.workspaceRoot,
  });

  /// Whether to write `AGENTS.md` and `CLAUDE.md`, or `null` to follow
  /// `beak.yaml`.
  final bool? instructions;

  /// Whether to materialize the docs, or `null` to follow `beak.yaml`.
  final bool? docs;

  /// The skill targets, or `null` to follow `beak.yaml` and then the folders
  /// the workspace has. Empty installs none.
  final List<BeakSkillTarget>? skills;

  /// Whether skills are installed at all. `beak prepare` leaves them alone.
  final bool installSkills;

  /// Writes nothing, and reports whether anything would change.
  final bool check;

  /// Writes nothing, and reports what would change.
  final bool dryRun;

  /// Replaces skills that were edited.
  final bool force;

  /// Undoes what Beak wrote instead of writing it.
  final bool remove;

  /// Renders the block and writes nothing.
  final bool print;

  /// The pub workspace root, when it cannot be found by walking up.
  final Directory? workspaceRoot;

  /// Whether this run leaves the disk alone.
  bool get isPlan => check || dryRun || print;
}

/// What happened to one file Beak keeps agent instructions in.
enum BeakFileAction {
  /// The file did not exist and now holds the block.
  created('created', 'create'),

  /// The file had no block; it was added at the end.
  appended('appended', 'append the block to'),

  /// The block was replaced by the current one.
  updated('updated', 'update'),

  /// Already as it should be.
  unchanged('unchanged', 'leave'),

  /// A `CLAUDE.md` that only imported `AGENTS.md`, or a file that held
  /// nothing but the block, was deleted.
  deleted('deleted', 'delete'),

  /// The block was taken out and the rest of the file kept.
  stripped('stripped', 'strip the block from');

  const BeakFileAction(this.pastTense, this.verb);

  /// How a report says it happened: `created`.
  final String pastTense;

  /// How a plan says it would: `create`.
  final String verb;
}

/// One file's fate.
final class BeakFileChange {
  /// Creates a change.
  const BeakFileChange({
    required this.label,
    required this.file,
    required this.action,
    this.isClaude = false,
  });

  /// The path as a person would name it: relative to the project.
  final String label;

  /// The file.
  final File file;

  /// What happens to it.
  final BeakFileAction action;

  /// Whether it is a `CLAUDE.md`.
  final bool isClaude;

  /// Whether the disk changes.
  bool get writes => action != BeakFileAction.unchanged;
}

/// Everything one run of the agent files did, or would do.
final class BeakAgentReport {
  /// Creates a report.
  const BeakAgentReport({
    required this.kind,
    required this.files,
    required this.problems,
    required this.notes,
    this.docs,
    this.skills,
    this.printedBlock,
    this.version,
  });

  /// The kind of project it ran in, or `null` for a project that no longer
  /// depends on Beak and is being cleaned up.
  final BeakProjectKind? kind;

  /// `AGENTS.md` and `CLAUDE.md` files, the project's first.
  final List<BeakFileChange> files;

  /// Files Beak refused to touch, and why: damaged markers, or a file that
  /// cannot be read.
  final List<String> problems;

  /// Things worth saying that are not failures.
  final List<String> notes;

  /// The docs, or `null` when they were left out.
  final BeakDocsResult? docs;

  /// The skills, or `null` when they were left out.
  final BeakSkillReport? skills;

  /// The rendered block of a `--print` run.
  final String? printedBlock;

  /// The Beak version the blocks name, or `null` for a removal.
  final String? version;

  /// Whether a file Beak keeps, an `AGENTS.md`, a `CLAUDE.md` or a skill,
  /// changes or would.
  ///
  /// The docs copy is not counted: it lives in `.dart_tool`, which no one
  /// commits, so a CI run that checks the committed files has nothing to say
  /// about it. See [docsPending].
  bool get hasChanges =>
      files.any((change) => change.writes) || (skills?.writes ?? false);

  /// Whether the docs copy in `.dart_tool` is missing or out of date.
  bool get docsPending => switch (docs) {
    BeakDocsReady(:final status) => status == BeakDocsStatus.pending,
    _ => false,
  };

  /// Whether a file was refused.
  bool get isDamaged => problems.isNotEmpty;

  /// The change to the project's own `AGENTS.md`, if it was handled.
  BeakFileChange? get agentsMd => files
      .where((change) => !change.isClaude && change.label == 'AGENTS.md')
      .firstOrNull;

  /// The lines `beak agents` prints, in the past tense for a run and as a
  /// plan for `--check` and `--dry-run`.
  List<String> describe({required bool planned}) {
    final lines = <String>[];
    final Iterable<BeakFileChange> changed = files.where((c) => c.writes);
    if (planned) {
      for (final change in changed) {
        lines.add('  would ${change.action.verb} ${change.label}');
      }
    } else if (changed.isNotEmpty) {
      lines.add(
        '  agents   ${changed.map((c) => '${c.label} ${c.action.pastTense}').join(' · ')}',
      );
    } else if (files.isNotEmpty) {
      lines.add('  agents   up to date');
    }
    if (docs case BeakDocsReady(
      :final version,
      :final status,
      :final directory,
    )) {
      lines.add(
        planned && status == BeakDocsStatus.pending
            ? '  would copy the docs of Beak $version to ${_shown(directory)}'
            : '  docs     Beak $version',
      );
    } else if (docs case BeakDocsUnavailable(:final reason)) {
      lines.add('  docs     not materialized: $reason');
    }
    if (skills case final BeakSkillReport report?) {
      lines.addAll(_skillLines(report, planned: planned));
    }
    for (final problem in problems) {
      lines.add('  ! $problem');
    }
    for (final note in notes) {
      lines.add('  $note');
    }
    return lines;
  }

  static List<String> _skillLines(
    BeakSkillReport report, {
    required bool planned,
  }) {
    final lines = <String>[];
    for (final target in BeakSkillTarget.values) {
      final Iterable<BeakSkillChange> ofTarget = report.changes.where(
        (change) => change.target == target,
      );
      if (ofTarget.isEmpty) {
        continue;
      }
      final counts = <BeakSkillOutcome, int>{};
      for (final change in ofTarget) {
        counts.update(change.outcome, (n) => n + 1, ifAbsent: () => 1);
      }
      final String summary = [
        for (final entry in counts.entries)
          if (entry.key != BeakSkillOutcome.unchanged)
            '${entry.value} ${planned ? 'to be ' : ''}${_skillWord(entry.key)}',
        if (counts.containsKey(BeakSkillOutcome.unchanged))
          '${counts[BeakSkillOutcome.unchanged]} up to date',
      ].join(', ');
      lines.add('  skills   ${target.directoryName}/skills: $summary');
    }
    for (final warning in report.warnings) {
      lines.add('  ! $warning');
    }
    return lines;
  }

  static String _skillWord(BeakSkillOutcome outcome) => switch (outcome) {
    BeakSkillOutcome.installed => 'installed',
    BeakSkillOutcome.updated => 'updated',
    BeakSkillOutcome.unchanged => 'up to date',
    BeakSkillOutcome.keptEdited => 'edited, kept',
    BeakSkillOutcome.ownedBySkillsCli =>
      'managed by `dart run skills@ get`, skipped',
    BeakSkillOutcome.removed => 'removed',
  };

  static String _shown(Directory directory) => p.relative(directory.path);
}

/// Writes (or plans) the files a coding agent reads in the project at
/// [projectRoot]: the managed block in `AGENTS.md`, the `CLAUDE.md` that
/// pairs with it, the version-matched docs, and the workflow skills.
///
/// Returns `null` when the project has no Beak app: no Beak dependency, or a
/// package of schema classes that depends on `beak_core` alone. With
/// [BeakAgentOptions.remove] it undoes instead, and needs no dependency: the
/// project may have dropped Beak already. Everything else is in the
/// [BeakAgentReport]: what was done (or, when [BeakAgentOptions.isPlan]
/// holds, would be), and what was refused. Idempotent: a second run finds
/// everything current and writes nothing.
BeakAgentReport? syncAgentFiles(
  Directory projectRoot, {
  BeakAgentOptions options = const BeakAgentOptions(),
}) {
  if (!options.remove && BeakProjectKind.isModelsOnly(projectRoot)) {
    return null;
  }
  final String packageName = BeakProjectConfig.packageNameOf(projectRoot);
  final BeakProjectConfig config = BeakProjectConfig.load(
    projectRoot,
    packageName: packageName,
  );
  final BeakProjectKind? kind = BeakProjectKind.detect(
    projectRoot,
    config: config,
  );
  if (options.remove) {
    return _Removal(projectRoot, options, kind).run();
  }
  if (kind == null) {
    return null;
  }
  return _Writing(
    projectRoot: projectRoot,
    packageName: packageName,
    config: config,
    kind: kind,
    options: options,
  ).run();
}

/// What the writing and the removing runs share: the files they touch, and
/// how.
abstract base class _Editor {
  _Editor(this.projectRoot, this.options)
    : workspace = BeakWorkspace.locate(
        projectRoot,
        workspaceRoot: options.workspaceRoot,
      ) {
    packages = BeakPackageConfig.read(workspace.packageConfigFile);
  }

  final Directory projectRoot;
  final BeakAgentOptions options;
  final BeakWorkspace workspace;
  late final BeakPackageConfig? packages;

  final files = <BeakFileChange>[];
  final problems = <String>[];
  final notes = <String>[];

  /// Puts [block] into [file], or records why it could not.
  void upsert({
    required File file,
    required String block,
    required String title,
    bool isClaude = false,
  }) {
    final String? existing = read(file);
    if (existing == null && file.existsSync()) {
      return;
    }
    switch (BeakManagedBlock.upsert(existing, block, title: title)) {
      case BeakBlockDamaged(:final reason):
        problems.add('${labelOf(file)}: $reason');
      case BeakBlockOk(:final content):
        final BeakFileAction action =
            existing == null || existing.trim().isEmpty
            ? BeakFileAction.created
            : content == existing
            ? BeakFileAction.unchanged
            : BeakManagedBlock.find(existing) is BeakBlockPresent
            ? BeakFileAction.updated
            : BeakFileAction.appended;
        files.add(
          BeakFileChange(
            label: labelOf(file),
            file: file,
            action: action,
            isClaude: isClaude,
          ),
        );
        if (action != BeakFileAction.unchanged && !options.isPlan) {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(content);
        }
    }
  }

  /// Takes the block out of [file] (whose text is [text]), deleting the file
  /// when nothing else is left.
  void stripBlock(File file, String text, {required bool isClaude}) {
    switch (BeakManagedBlock.remove(text)) {
      case BeakBlockDamaged(:final reason):
        problems.add('${labelOf(file)}: $reason');
      case BeakBlockOk(:final content) when content == text:
        return;
      case BeakBlockOk(:final content):
        final bool empty = content.trim().isEmpty;
        files.add(
          BeakFileChange(
            label: labelOf(file),
            file: file,
            action: empty ? BeakFileAction.deleted : BeakFileAction.stripped,
            isClaude: isClaude,
          ),
        );
        if (!options.isPlan) {
          if (empty) {
            file.deleteSync();
          } else {
            file.writeAsStringSync(content);
          }
        }
    }
  }

  /// The text of [file], or `null` when it is missing or not UTF-8 (which is
  /// recorded as a problem).
  String? read(File file) {
    if (!file.existsSync()) {
      return null;
    }
    try {
      return utf8.decode(file.readAsBytesSync());
    } on FormatException {
      problems.add('${labelOf(file)}: not valid UTF-8, left alone');
      return null;
    }
  }

  /// [file] as a person would name it: relative to the project.
  String labelOf(File file) =>
      p.posix.joinAll(p.split(p.relative(file.path, from: projectRoot.path)));
}

/// A run that undoes what Beak wrote: the blocks, a `CLAUDE.md` that only
/// imports `AGENTS.md`, and the skills nobody edited.
final class _Removal extends _Editor {
  _Removal(super.projectRoot, super.options, this.kind);

  final BeakProjectKind? kind;

  BeakAgentReport run() {
    strip(projectRoot);
    if (workspace.isWorkspaceMember) {
      strip(workspace.workspaceRoot);
    }
    return BeakAgentReport(
      kind: kind,
      files: files,
      problems: problems,
      notes: notes,
      skills: uninstallSkills(
        workspace: workspace,
        force: options.force,
        dryRun: options.isPlan,
      ),
    );
  }

  void strip(Directory directory) {
    final claude = File(p.join(directory.path, 'CLAUDE.md'));
    if (claude.existsSync() && !FileSystemEntity.isLinkSync(claude.path)) {
      final String? text = read(claude);
      if (text == BeakClaudeMd.importOnly) {
        files.add(
          BeakFileChange(
            label: labelOf(claude),
            file: claude,
            action: BeakFileAction.deleted,
            isClaude: true,
          ),
        );
        if (!options.isPlan) {
          claude.deleteSync();
        }
      } else if (text != null) {
        stripBlock(claude, text, isClaude: true);
      }
    }
    final agents = File(p.join(directory.path, 'AGENTS.md'));
    if (agents.existsSync() && !FileSystemEntity.isLinkSync(agents.path)) {
      final String? text = read(agents);
      if (text != null) {
        stripBlock(agents, text, isClaude: false);
      }
    }
  }
}

/// A run that writes the agent files of a project that depends on Beak.
final class _Writing extends _Editor {
  _Writing({
    required Directory projectRoot,
    required this.packageName,
    required this.config,
    required this.kind,
    required BeakAgentOptions options,
  }) : super(projectRoot, options);

  final String packageName;
  final BeakProjectConfig config;
  final BeakProjectKind kind;

  /// The instructions the settings and the flags leave on: `all`, `package`
  /// or `none`.
  BeakAgentInstructions get _scope {
    final BeakAgentInstructions configured = config.agents.instructions;
    return switch (options.instructions) {
      false => BeakAgentInstructions.none,
      true when configured == BeakAgentInstructions.none =>
        BeakAgentInstructions.all,
      _ => configured,
    };
  }

  BeakAgentReport run() {
    final BeakDocsResult? docs = options.docs ?? config.agents.docs
        ? materializeDocs(workspace, packages: packages, dryRun: options.isPlan)
        : null;
    final BeakSkillReport? skills = _skills();
    String? printed;
    if (_scope != BeakAgentInstructions.none || options.print) {
      printed = _instructions(skills);
    }
    return BeakAgentReport(
      kind: kind,
      files: files,
      problems: problems,
      notes: notes,
      docs: options.print ? null : docs,
      skills: skills,
      printedBlock: options.print ? printed : null,
      version: _version(),
    );
  }

  /// Installs the skills, when this run does.
  BeakSkillReport? _skills() {
    if (!options.installSkills || options.print) {
      return null;
    }
    final List<BeakSkillTarget> targets =
        options.skills ??
        defaultSkillTargets(workspace, configured: config.agents.skills);
    if (targets.isEmpty) {
      return null;
    }
    final BeakPackageConfig? resolved = packages;
    if (resolved == null) {
      notes.add(
        'skills   not installed: run `flutter pub get`, then `beak agents`',
      );
      return null;
    }
    return installSkills(
      workspace: workspace,
      config: resolved,
      targets: targets,
      force: options.force,
      dryRun: options.isPlan,
    );
  }

  /// Writes the blocks, and returns the project's rendered block.
  String _instructions(BeakSkillReport? skillReport) {
    final String skills = _skillsText(skillReport);
    final String version = _version();
    final String block = _render(
      kind.block,
      _valuesFor(
        block: kind.block,
        directory: projectRoot,
        skills: skills,
        version: version,
      ),
    );
    if (options.print) {
      return block;
    }
    upsert(
      file: File(p.join(projectRoot.path, 'AGENTS.md')),
      block: block,
      title: BeakProjectConfig.titleCase(packageName),
    );
    _pair(projectRoot, block);
    if (workspace.isWorkspaceMember && _scope == BeakAgentInstructions.all) {
      final Directory root = workspace.workspaceRoot;
      final String rootBlock = _render(
        BeakBlockKind.workspaceRoot,
        _valuesFor(
          block: BeakBlockKind.workspaceRoot,
          directory: root,
          skills: skills,
          version: version,
        ),
      );
      upsert(
        file: File(p.join(root.path, 'AGENTS.md')),
        block: rootBlock,
        title: BeakProjectConfig.titleCase(p.basename(root.path)),
      );
      _pair(root, rootBlock);
    }
    return block;
  }

  /// Pairs the `AGENTS.md` of [directory], whose block is [block], with a
  /// `CLAUDE.md`.
  void _pair(Directory directory, String block) {
    final claude = File(p.join(directory.path, 'CLAUDE.md'));
    switch (BeakClaudeMd.plan(directory)) {
      case BeakClaudeCreate():
        files.add(
          BeakFileChange(
            label: labelOf(claude),
            file: claude,
            action: BeakFileAction.created,
            isClaude: true,
          ),
        );
        if (!options.isPlan) {
          claude.writeAsStringSync(BeakClaudeMd.importOnly);
        }
      case BeakClaudeSatisfied():
        return;
      case BeakClaudeCarry():
        upsert(file: claude, block: block, title: 'CLAUDE', isClaude: true);
    }
  }

  /// The Beak version the block names: the bundle's, else the resolved
  /// package's, else this CLI's.
  String _version() {
    final BeakResolvedPackage? core = packages?.core;
    if (core != null) {
      final manifest = File(
        p.join(core.root.path, 'doc', 'agent-docs', 'manifest.json'),
      );
      if (manifest.existsSync()) {
        try {
          if (jsonDecode(manifest.readAsStringSync()) case {
            'beak': final String version,
          }) {
            return version;
          }
        } on FormatException {
          // Fall through to the package's own version.
        }
      }
    }
    return core?.version ?? packages?.umbrella?.version ?? beakCliVersion;
  }

  /// The installed skills as the block lists them, after this run.
  String _skillsText(BeakSkillReport? report) {
    final present = <(BeakSkillTarget, String)>{
      for (final skill in installedSkills(workspace, packages))
        (skill.target, skill.name),
    };
    for (final change in report?.changes ?? const <BeakSkillChange>[]) {
      final pair = (change.target, change.name);
      switch (change.outcome) {
        case BeakSkillOutcome.installed:
          present.add(pair);
        case BeakSkillOutcome.removed:
          present.remove(pair);
        case _:
      }
    }
    final List<String> names = {for (final (_, name) in present) name}.toList()
      ..sort();
    return names.isEmpty
        ? 'run `beak agents` to install them'
        : names.map((name) => '`$name`').join(', ');
  }

  BeakBlockValues _valuesFor({
    required BeakBlockKind block,
    required Directory directory,
    required String skills,
    required String version,
  }) {
    final String docsIndex = p.posix.joinAll(
      p.split(
        p.relative(
          p.join(workspace.docsDirectory.path, 'ai-index.md'),
          from: directory.path,
        ),
      ),
    );
    final bool isServerpod = kind == BeakProjectKind.serverpodAdmin;
    final Set<String> dependencies = BeakProjectKind.dependenciesOf(
      projectRoot,
    );
    final String base = packageName.endsWith('_admin')
        ? packageName.substring(0, packageName.length - '_admin'.length)
        : packageName;
    return BeakBlockValues(
      version: version,
      docsIndex: docsIndex,
      skills: skills,
      schemaGlob: _schemaGlob(),
      panelEntry: config.panel.entrypointPath,
      adminDir: workspace.projectPathInWorkspace,
      serverPkg: isServerpod ? '${base}_server' : null,
      clientPkg: isServerpod
          ? dependencies
                    .where((name) => name.endsWith('_client'))
                    .firstOrNull ??
                '${base}_client'
          : null,
      schemaPkg: isServerpod
          ? dependencies.where((name) => name.endsWith('_beak')).firstOrNull ??
                '${base}_beak'
          : null,
      mainIsGenerated: _mainIsGenerated(),
    );
  }

  /// Where the schema classes are, from where the reader found them.
  String _schemaGlob() {
    const golden = 'lib/resources/*/models/*.dart';
    const flat = 'lib/models/*.dart';
    final (schemas, _) = BeakSchemaReader(projectRoot).read();
    final found = <String>{};
    for (final schema in schemas) {
      final String path = BeakSchemaEmitter.partPathOf(schema);
      if (RegExp(r'^lib/resources/[^/]+/models/[^/]+$').hasMatch(path)) {
        found.add(golden);
      } else if (RegExp(r'^lib/models/[^/]+$').hasMatch(path)) {
        found.add(flat);
      }
    }
    if (found.isEmpty) {
      return golden;
    }
    return [golden, flat].where(found.contains).join('`, `');
  }

  /// Whether `lib/main.dart` is the file Beak generates.
  bool _mainIsGenerated() {
    if (config.panel.entrypoint != null) {
      return false;
    }
    final main = File(p.join(projectRoot.path, 'lib', 'main.dart'));
    return !main.existsSync() ||
        main.readAsStringSync().startsWith(BeakAuthoredMain.generatedMarker);
  }

  /// [block] rendered from the resolved bundle's template, the workspace's
  /// copy of it, or the CLI's own, in that order of preference.
  String _render(BeakBlockKind block, BeakBlockValues values) {
    final name = '${block.templateName}.md';
    final candidates = <File>[
      if (packages?.core case final BeakResolvedPackage core)
        File(
          p.join(
            core.root.path,
            'doc',
            'agent-docs',
            '_agents',
            'blocks',
            name,
          ),
        ),
      File(p.join(workspace.docsDirectory.path, '_agents', 'blocks', name)),
    ];
    for (final candidate in candidates) {
      if (!candidate.existsSync()) {
        continue;
      }
      try {
        return renderBlock(candidate.readAsStringSync(), values);
      } on BeakTemplateException catch (error) {
        notes.add(
          "the bundle's ${block.templateName} template could not be "
          "rendered (${error.message}); used the CLI's",
        );
        break;
      }
    }
    return renderBlock(block.fallbackTemplate, values);
  }
}
