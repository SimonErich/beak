import 'dart:io';

import 'package:path/path.dart' as p;

import 'beak_managed_block.dart';

/// Whether [claudeMd] imports the `AGENTS.md` beside it: a line that is
/// only `@AGENTS.md` (or `@./AGENTS.md`).
///
/// Claude Code reads `AGENTS.md` only when there is no `CLAUDE.md`, and a
/// `CLAUDE.md` pulls another file in with an `@` import on a line of its
/// own.
bool claudeMdImportsAgents(String claudeMd) =>
    RegExp(r'^@\.?/?AGENTS\.md\s*$', multiLine: true).hasMatch(claudeMd);

/// What `beak agents` does about `CLAUDE.md` in one directory.
sealed class BeakClaudePlan {
  const BeakClaudePlan();
}

/// Neither `CLAUDE.md` nor `.claude/CLAUDE.md` exists: create a `CLAUDE.md`
/// that imports `AGENTS.md`.
final class BeakClaudeCreate extends BeakClaudePlan {
  /// Creates the plan.
  const BeakClaudeCreate();
}

/// Something already makes Claude Code read `AGENTS.md`, or the user keeps
/// their Claude setup in `.claude/`: leave it alone.
final class BeakClaudeSatisfied extends BeakClaudePlan {
  /// Creates the plan.
  const BeakClaudeSatisfied();
}

/// `CLAUDE.md` exists and does not import `AGENTS.md`: put the managed block
/// into it too.
///
/// Adding the import instead could duplicate content the user deliberately
/// split between the two files.
final class BeakClaudeCarry extends BeakClaudePlan {
  /// Creates the plan for a `CLAUDE.md` whose text is [existing].
  const BeakClaudeCarry(this.existing);

  /// The current text of `CLAUDE.md`.
  final String existing;
}

/// Whether Claude Code reads a directory's `AGENTS.md`.
enum BeakClaudePairing {
  /// A `CLAUDE.md` imports `AGENTS.md`, carries the block, or is the same
  /// file.
  paired,

  /// `AGENTS.md` exists and no `CLAUDE.md` reads it.
  unread,

  /// `.claude/CLAUDE.md` writes `@AGENTS.md`, which resolves next to that
  /// file, where there is no `AGENTS.md`.
  brokenDotClaudeImport,
}

/// The rules that pair `AGENTS.md` with `CLAUDE.md`.
///
/// ```dart
/// switch (BeakClaudeMd.plan(directory)) {
///   case BeakClaudeCreate():
///     File('CLAUDE.md').writeAsStringSync(BeakClaudeMd.importOnly);
///   case BeakClaudeCarry(:final existing):
///   // Upsert the managed block into `existing`.
///   case BeakClaudeSatisfied():
///   // Nothing to do.
/// }
/// ```
abstract final class BeakClaudeMd {
  /// The `CLAUDE.md` Beak creates.
  static const String importOnly = '@AGENTS.md\n';

  /// What to do about `CLAUDE.md` in [directory], whose `AGENTS.md` is (or
  /// is about to be) written.
  ///
  /// 1. No `CLAUDE.md` and no `.claude/CLAUDE.md`: create one.
  /// 2. A `CLAUDE.md` that imports `AGENTS.md`, or is the same file: leave it.
  /// 3. A `CLAUDE.md` without the import: carry the block into it.
  /// 4. Only `.claude/CLAUDE.md`: leave it; `beak doctor` says whether it
  ///    reads `AGENTS.md`.
  static BeakClaudePlan plan(Directory directory) {
    final String claude = p.join(directory.path, 'CLAUDE.md');
    if (FileSystemEntity.typeSync(claude, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return File(p.join(directory.path, '.claude', 'CLAUDE.md')).existsSync()
          ? const BeakClaudeSatisfied()
          : const BeakClaudeCreate();
    }
    if (_isSameFile(directory)) {
      return const BeakClaudeSatisfied();
    }
    final String text = File(claude).readAsStringSync();
    return claudeMdImportsAgents(text)
        ? const BeakClaudeSatisfied()
        : BeakClaudeCarry(text);
  }

  /// Whether Claude Code reads the `AGENTS.md` in [directory].
  static BeakClaudePairing pairing(Directory directory) {
    final String claude = p.join(directory.path, 'CLAUDE.md');
    if (FileSystemEntity.typeSync(claude, followLinks: false) !=
        FileSystemEntityType.notFound) {
      if (_isSameFile(directory)) {
        return BeakClaudePairing.paired;
      }
      final String text = File(claude).readAsStringSync();
      return claudeMdImportsAgents(text) ||
              BeakManagedBlock.find(text) is BeakBlockPresent
          ? BeakClaudePairing.paired
          : BeakClaudePairing.unread;
    }
    final dotClaude = File(p.join(directory.path, '.claude', 'CLAUDE.md'));
    if (!dotClaude.existsSync()) {
      return BeakClaudePairing.unread;
    }
    final String text = dotClaude.readAsStringSync();
    if (RegExp(r'^@\.\./AGENTS\.md\s*$', multiLine: true).hasMatch(text)) {
      return BeakClaudePairing.paired;
    }
    if (claudeMdImportsAgents(text)) {
      return File(p.join(directory.path, '.claude', 'AGENTS.md')).existsSync()
          ? BeakClaudePairing.paired
          : BeakClaudePairing.brokenDotClaudeImport;
    }
    return BeakClaudePairing.unread;
  }

  /// Whether `CLAUDE.md` and `AGENTS.md` in [directory] are one file, by
  /// link or by content identity. A link that names `AGENTS.md` counts even
  /// before that file exists.
  static bool _isSameFile(Directory directory) {
    final String claude = p.join(directory.path, 'CLAUDE.md');
    final String agents = p.join(directory.path, 'AGENTS.md');
    if (FileSystemEntity.isLinkSync(claude) &&
        p.basename(Link(claude).targetSync()) == 'AGENTS.md') {
      return true;
    }
    if (FileSystemEntity.isLinkSync(agents) &&
        p.basename(Link(agents).targetSync()) == 'CLAUDE.md') {
      return true;
    }
    return File(agents).existsSync() &&
        File(claude).existsSync() &&
        FileSystemEntity.identicalSync(claude, agents);
  }
}
