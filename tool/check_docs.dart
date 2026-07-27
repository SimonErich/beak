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

/// Fence languages whose body is a transcript rather than a quotation.
///
/// A `console` block titled with a file name is showing what running it
/// prints, not what the file contains.
const Set<String> transcriptLanguages = {
  '',
  'console',
  'bash',
  'sh',
  'shell',
  'text',
  'output',
  'diff',
};

/// A line that says "and some more of the file here".
///
/// Anything opening with `...`, optionally behind a comment marker and
/// optionally followed by a note about what was left out: `// ...`,
/// `// ... roughly fifty arms ...`, `# ...`, a bare `...`. A quotation is
/// checked chunk by chunk between these, so an abridged quote stays honest
/// without having to be complete.
final RegExp elisionMarker = RegExp(r'^(?://+|#+|/\*+|<!--)?\s*\.\.\.');

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

  problems.addAll(checkQuotations(path, lines));
  return problems;
}

/// The problems in the code fences of [lines] that claim to quote a file.
///
/// A fence titled with a repository path is a quotation, and a quotation that
/// has drifted from its source is worse than no quotation: the reader trusts
/// it, opens the file, and finds something else. Every such fence is checked
/// against the file it names.
///
/// A fence may abridge with an elision marker, so the body is compared chunk
/// by chunk between them, and indentation is ignored — a class member quoted
/// on its own is still that member.
List<DocProblem> checkQuotations(String path, List<String> lines) {
  final problems = <DocProblem>[];
  for (final quotation in _quotationsIn(lines)) {
    final file = File(quotation.target);
    if (!file.existsSync()) {
      // Already reported as a missing path.
      continue;
    }
    final List<String> source = _significant(
      file.readAsStringSync().split('\n'),
    );
    for (final chunk in _chunksOf(quotation.body)) {
      if (_containsRun(source, chunk)) {
        continue;
      }
      problems.add(
        DocProblem(
          path,
          'the fence titled "${quotation.target}" does not quote it: '
          '${_whyNot(source, chunk)}. Correct the code, or drop the title if '
          'the block is illustrative.',
          line: quotation.line,
        ),
      );
      // One report per fence: the first mismatch is the one to look at.
      break;
    }
  }
  return problems;
}

/// One fence that claims to quote a repository file.
final class _Quotation {
  const _Quotation({
    required this.target,
    required this.line,
    required this.body,
  });

  /// The repository path the fence names.
  final String target;

  /// The 1-based line the fence opens on.
  final int line;

  /// The fence's contents.
  final List<String> body;
}

/// Every quotation fence in [lines].
Iterable<_Quotation> _quotationsIn(List<String> lines) sync* {
  final opener = RegExp(r'^(\s*)```(\w*)\s+title="([^"]+)"');
  for (var index = 0; index < lines.length; index += 1) {
    final RegExpMatch? match = opener.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }
    final String indent = match.group(1)!;
    final String language = match.group(2)!;
    final String target = match.group(3)!;
    final int close = _closingFence(lines, index + 1, indent);
    if (close == -1) {
      continue;
    }
    final bool quotesRepo =
        target.startsWith('packages/') ||
        target.startsWith('examples/') ||
        target.startsWith('tool/');
    if (quotesRepo && !transcriptLanguages.contains(language)) {
      yield _Quotation(
        target: target,
        line: index + 1,
        body: lines.sublist(index + 1, close),
      );
    }
    index = close;
  }
}

/// The index of the fence closing the one opened at [from], or -1.
int _closingFence(List<String> lines, int from, String indent) {
  for (var index = from; index < lines.length; index += 1) {
    if (lines[index] == '$indent```') {
      return index;
    }
  }
  return -1;
}

/// [lines] reduced to what a comparison should care about: trimmed, with
/// blank lines dropped.
List<String> _significant(List<String> lines) => [
  for (final line in lines)
    if (line.trim().isNotEmpty) line.trim(),
];

/// [body] split on elision markers into the runs that must each appear.
///
/// A chunk of one line is skipped: a single line in isolation is as likely to
/// be a paraphrase of a signature as a quotation of one, and reporting it
/// would cost more than it catches.
List<List<String>> _chunksOf(List<String> body) {
  final chunks = <List<String>>[];
  var current = <String>[];
  for (final line in _significant(body)) {
    if (elisionMarker.hasMatch(line)) {
      if (current.length > 1) {
        chunks.add(current);
      }
      current = <String>[];
      continue;
    }
    current.add(line);
  }
  if (current.length > 1) {
    chunks.add(current);
  }
  return chunks;
}

/// Why [run] is not in [source], in the words a writer can act on.
///
/// A line that appears nowhere is the useful thing to name. When every line
/// is present but the run is not, the quotation reordered or interrupted
/// them, which is worth saying differently.
String _whyNot(List<String> source, List<String> run) {
  for (final line in run) {
    if (!source.contains(line)) {
      return '"${_clip(line)}" is not in that file';
    }
  }
  return 'its ${run.length} lines are all in that file but not together, so '
      'the quotation reorders or interrupts them (starting at '
      '"${_clip(run.first)}")';
}

/// [line], short enough to read in a terminal.
String _clip(String line) =>
    line.length <= 60 ? line : '${line.substring(0, 57)}...';

/// A line that is prose about the code rather than the code.
///
/// A page quoting a declaration may leave its doc comment out to stay short,
/// and that is still a faithful quotation. Quoting one that has since changed
/// is not, so a comment the fence *does* include still has to match.
bool _isComment(String line) =>
    line.startsWith('//') ||
    line.startsWith('/*') ||
    line.startsWith('*') ||
    line.startsWith('#');

/// Whether [run] appears in [source] in order, allowing the source's comment
/// lines to be passed over where the quotation omits them.
bool _containsRun(List<String> source, List<String> run) {
  if (run.isEmpty || run.length > source.length) {
    return false;
  }
  for (var start = 0; start < source.length; start += 1) {
    if (source[start] != run.first) {
      continue;
    }
    var index = start;
    var offset = 0;
    while (offset < run.length && index < source.length) {
      if (source[index] == run[offset]) {
        index += 1;
        offset += 1;
        continue;
      }
      if (_isComment(source[index]) && !_isComment(run[offset])) {
        index += 1;
        continue;
      }
      break;
    }
    if (offset == run.length) {
      return true;
    }
  }
  return false;
}
