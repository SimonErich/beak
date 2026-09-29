import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../agents/beak_agent_files.dart';
import '../agents/beak_docs_bundle.dart';
import '../agents/beak_project_kind.dart';
import '../agents/beak_skill_installer.dart';
import '../cli_runner.dart';

/// Writes what a coding agent needs to work in a Beak project: the rules in
/// `AGENTS.md`, the `CLAUDE.md` that makes Claude Code read it, the docs of
/// the Beak version the project resolved, and Beak's workflow skills.
///
/// Beak only edits between two marker comments in `AGENTS.md`, keeps
/// everything around them byte for byte, and refuses to touch a file whose
/// markers are damaged. Every step is idempotent, so a second run writes
/// nothing, and `--check` makes that a CI gate. `beak.yaml`'s `agents:`
/// section turns any of it off; `--print` renders the block for a project
/// that would rather paste it in.
///
/// ```console
/// $ beak agents
///   agents   AGENTS.md created · CLAUDE.md created
///   docs     Beak 0.9.0
/// $ beak agents --check
/// ```
final class AgentsCommand extends Command<int> {
  /// Creates the command against [environment].
  AgentsCommand(this.environment) {
    argParser
      ..addOption(
        'skills',
        help:
            'Where to install the workflow skills: any of claude, agents and '
            'cursor, comma separated, or none. Defaults to agents.skills in '
            'beak.yaml, then the agent folders the workspace has.',
        valueHelp: 'claude,agents,cursor|none',
      )
      ..addFlag(
        'instructions',
        help: 'Write AGENTS.md and CLAUDE.md. Defaults to beak.yaml.',
      )
      ..addFlag(
        'docs',
        help: 'Copy the docs to .dart_tool/beak/docs. Defaults to beak.yaml.',
      )
      ..addFlag(
        'check',
        help:
            'Write nothing; exit 1 when AGENTS.md, CLAUDE.md or a skill would '
            'change.',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Write nothing; print what would change.',
        negatable: false,
      )
      ..addFlag(
        'print',
        help: 'Print the AGENTS.md block and write nothing.',
        negatable: false,
      )
      ..addFlag(
        'force',
        help: 'Replace skills that were edited.',
        negatable: false,
      )
      ..addFlag(
        'remove',
        help:
            'Undo it: strip the blocks, delete a CLAUDE.md that only imports '
            'AGENTS.md, and uninstall unedited skills.',
        negatable: false,
      )
      ..addOption(
        'root',
        help:
            'The pub workspace root, when it cannot be found by walking up '
            'from this project.',
        valueHelp: 'dir',
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'agents';

  @override
  String get description =>
      'Write the AGENTS.md block, CLAUDE.md, docs and skills for coding '
      'agents.';

  @override
  String get invocation =>
      'beak agents [--skills claude,agents,cursor|none] '
      '[--[no-]instructions] [--[no-]docs] [--check] [--dry-run] [--print] '
      '[--force] [--remove] [--root <dir>]';

  @override
  Future<int> run() async {
    final ArgResults? args = argResults;
    if (args == null || args.rest.isNotEmpty) {
      throw UsageException('beak agents takes no arguments.', invocation);
    }
    final bool check = args.flag('check');
    final bool dryRun = args.flag('dry-run');
    final bool print = args.flag('print');
    final BeakAgentReport? report = syncAgentFiles(
      environment.rootDirectory,
      options: BeakAgentOptions(
        instructions: args.wasParsed('instructions')
            ? args.flag('instructions')
            : null,
        docs: args.wasParsed('docs') ? args.flag('docs') : null,
        skills: _skills(args['skills']),
        check: check,
        dryRun: dryRun,
        force: args.flag('force'),
        remove: args.flag('remove'),
        print: print,
        workspaceRoot: switch (args['root']) {
          final String path => Directory(p.absolute(path)),
          _ => null,
        },
      ),
    );
    if (report == null) {
      environment.out.writeln(BeakProjectKind.notABeakProject);
      return 1;
    }
    if (print && report.printedBlock != null) {
      environment.out.writeln(report.printedBlock);
      return 0;
    }
    final bool planned = check || dryRun;
    for (final line in report.describe(planned: planned)) {
      environment.out.writeln(line);
    }
    if (report.isDamaged) {
      return 1;
    }
    if (check && report.hasChanges) {
      environment.out.writeln('  run `beak agents` to bring them up to date');
      return 1;
    }
    return 0;
  }

  /// The targets `--skills` names: `null` when it is not given, empty for
  /// `none`.
  List<BeakSkillTarget>? _skills(Object? value) {
    if (value is! String) {
      return null;
    }
    if (value.trim() == 'none') {
      return const [];
    }
    final targets = <BeakSkillTarget>[];
    for (final label in value.split(',')) {
      final BeakSkillTarget? target = BeakSkillTarget.parse(label);
      if (target == null) {
        throw UsageException(
          '--skills takes claude, agents, cursor or none (got "$label").',
          invocation,
        );
      }
      if (!targets.contains(target)) {
        targets.add(target);
      }
    }
    return targets;
  }
}

/// Brings a project's agent files up to date after a command that changes
/// what they describe, printing one line about it.
///
/// This is what `beak prepare`, `beak create` and `beak init` call. It never
/// fails the command that called it: a problem becomes a printed line, so a
/// missing `pub get` or a damaged marker cannot stop code generation. A
/// project without a Beak dependency is left alone without a word. Skills
/// are installed only when [installSkills] says so; `prepare` leaves them
/// to `beak agents`.
BeakAgentReport? refreshAgentFiles(
  BeakCliEnvironment environment, {
  bool installSkills = false,
}) {
  try {
    final BeakAgentReport? report = syncAgentFiles(
      environment.rootDirectory,
      options: BeakAgentOptions(installSkills: installSkills),
    );
    if (report == null) {
      return null;
    }
    environment.out.writeln('  agents     ${_summaryOf(report, environment)}');
    for (final problem in report.problems) {
      environment.out.writeln('  !          $problem');
    }
    return report;
  } on Exception catch (error) {
    environment.out.writeln('  agents     skipped: $error');
    return null;
  }
}

/// One line about [report]: the files, then the docs.
String _summaryOf(BeakAgentReport report, BeakCliEnvironment environment) {
  final parts = <String>[];
  final changed = report.files.where((change) => change.writes);
  if (changed.isNotEmpty) {
    parts.addAll(
      changed.map((change) => '${change.label} ${change.action.pastTense}'),
    );
  } else if (report.files.isNotEmpty) {
    parts.add('up to date');
  }
  switch (report.docs) {
    case BeakDocsReady(:final version, :final indexFile):
      parts.add(
        'docs Beak $version, '
        '${p.posix.joinAll(p.split(p.relative(indexFile.path, from: environment.rootDirectory.path)))}',
      );
    case BeakDocsUnavailable(:final reason):
      parts.add('docs not materialized: $reason');
    case null:
      break;
  }
  return parts.isEmpty ? 'nothing to do' : parts.join(' · ');
}
