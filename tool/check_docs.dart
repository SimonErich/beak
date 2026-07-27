/// Structural checks for the documentation (`melos run check-docs`).
///
/// MkDocs' `--strict` catches broken links and pages missing from the nav.
/// It cannot catch the things this file checks: a code fence claiming to
/// quote a file that no longer exists, a page with no front matter, a snippet
/// include pointing at a moved file, or a banned phrase from the style guide.
///
/// Run from the repo root. Exits non-zero with one line per problem.
library;

import 'dart:io';

/// Phrases the style guide bans, lowercased.
///
/// Each one is a promise the reader has to take on faith. The docs make
/// claims and show code instead.
const List<String> bannedPhrases = [
  'seamless',
  'effortless',
  'blazing',
  'supercharge',
  'revolutionary',
  'magic ',
  'delightful',
];

/// Directories under `docs/` that are not published and are not checked.
const Set<String> unpublishedDirs = {'_internal', 'assets'};

/// One problem found in one file.
final class DocProblem {
  /// Creates a problem at [path], optionally at [line].
  const DocProblem(this.path, this.message, {this.line});

  /// Path relative to the repo root.
  final String path;

  /// The 1-based line, when the problem has one.
  final int? line;

  /// What is wrong, in the imperative.
  final String message;

  @override
  String toString() => '$path${line == null ? '' : ':$line'}: $message';
}

void main() {
  final docs = Directory('docs');
  if (!docs.existsSync()) {
    stderr.writeln('No docs/ directory — run this from the repo root.');
    exit(2);
  }

  final problems = <DocProblem>[];
  for (final file in _publishedPages(docs)) {
    problems.addAll(checkPage(file.path, file.readAsStringSync()));
  }

  if (problems.isEmpty) {
    stdout.writeln('Docs check passed.');
    return;
  }
  stderr.writeln('Docs check failed:');
  for (final problem in problems) {
    stderr.writeln('  $problem');
  }
  exit(1);
}

/// Every published Markdown page under [docs], in path order.
Iterable<File> _publishedPages(Directory docs) sync* {
  final entities = docs.listSync(recursive: true, followLinks: false).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entity in entities) {
    if (entity is! File || !entity.path.endsWith('.md')) {
      continue;
    }
    final List<String> segments = entity.uri.pathSegments;
    if (segments.any(unpublishedDirs.contains)) {
      continue;
    }
    yield entity;
  }
}

/// The problems in [content], a page at [path].
///
/// Pure, so the checks are testable without a filesystem full of fixtures —
/// except the two that must look at the tree, which take the repo as it is.
List<DocProblem> checkPage(String path, String content) {
  final problems = <DocProblem>[];
  final lines = content.split('\n');

  if (!content.startsWith('---\n')) {
    problems.add(
      DocProblem(
        path,
        'no front matter (needs title and '
        'description)',
      ),
    );
  } else {
    final int end = lines.indexOf('---', 1);
    final String front = end == -1 ? '' : lines.sublist(1, end).join('\n');
    for (final key in const ['title:', 'description:']) {
      if (!front.contains(key)) {
        problems.add(DocProblem(path, 'front matter has no "$key"'));
      }
    }
  }

  if (!content.contains('## Continue reading')) {
    problems.add(
      DocProblem(
        path,
        'no "## Continue reading" section — every page points '
        'at the next two',
      ),
    );
  }

  for (var index = 0; index < lines.length; index += 1) {
    final String line = lines[index];
    final int number = index + 1;

    // A fence that names a file is quoting it; the file has to be there.
    final RegExpMatch? title = RegExp(r'title="([^"]+)"').firstMatch(line);
    if (title != null && line.trimLeft().startsWith('```')) {
      final String named = title.group(1)!;
      if (named.startsWith('apps/')) {
        problems.add(
          DocProblem(
            path,
            'fence titled "$named" — apps/ is now examples/',
            line: number,
          ),
        );
      } else if ((named.startsWith('packages/') ||
              named.startsWith('examples/') ||
              named.startsWith('tool/')) &&
          !File(named).existsSync()) {
        problems.add(
          DocProblem(
            path,
            'fence titled "$named", which does not exist',
            line: number,
          ),
        );
      }
    }

    // A snippet include reads the file at build time; a moved file would
    // publish an empty block.
    final RegExpMatch? include = RegExp(
      r'^\s*--8<--\s+"([^"]+)"',
    ).firstMatch(line);
    if (include != null) {
      final String target = include.group(1)!.split(':').first;
      if (!File(target).existsSync()) {
        problems.add(
          DocProblem(
            path,
            'snippet includes "$target", which does not exist',
            line: number,
          ),
        );
      }
    }

    final String lowered = line.toLowerCase();
    for (final banned in bannedPhrases) {
      if (lowered.contains(banned)) {
        problems.add(
          DocProblem(path, 'style guide bans "${banned.trim()}"', line: number),
        );
      }
    }
  }

  return problems;
}
