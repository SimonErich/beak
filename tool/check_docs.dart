/// Structural checks for the documentation (`melos run check-docs`).
///
/// MkDocs' `--strict` catches broken links and pages missing from the nav.
/// It cannot catch the things this file checks: a code fence claiming to
/// quote a file that no longer exists, a page with no front matter, a snippet
/// include pointing at a moved file, or a banned phrase from the style guide.
///
/// The style guide's "Banned" section is enforced from [enforcedBans]. The
/// bans still waiting on a copy-editing pass live in [pendingBans]; they are
/// printed on every run and fail nothing.
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

/// One entry from the style guide's "Banned" section, and how to spot it.
///
/// [pattern] runs over [proseOf] a line that sits outside every code fence. A
/// banned word inside a fence belongs to the source being quoted, and changing
/// it would break the quotation check below.
final class BannedPhrase {
  /// Bans [label], found by [pattern], with [instead] naming the way out.
  const BannedPhrase({
    required this.label,
    required this.pattern,
    required this.instead,
  });

  /// What is banned, phrased the way the style guide phrases it.
  final String label;

  /// Matches an occurrence of [label] in a line of prose.
  final RegExp pattern;

  /// What to write instead.
  final String instead;

  /// The problem text reported for a line that matches.
  String get message => 'style guide bans $label ($instead)';
}

/// A ban on the marketing word [word] and the forms built on it.
///
/// The trailing `\w*` is what catches "seamlessly" and "magically", which are
/// the forms a writer actually reaches for.
BannedPhrase marketingWord(String word) => BannedPhrase(
  label: '"$word"',
  pattern: RegExp('\\b$word\\w*', caseSensitive: false),
  instead: 'state what it does and show the code',
);

/// The style guide's marketing words that are safe to match as words.
///
/// Each one is a promise the reader has to take on faith. The docs make
/// claims and show code instead. The other two on the guide's list, "just"
/// and "unlock", also mean something honest in these docs, so they get their
/// own rules: [belittlingJust] and [marketingUnlock].
final List<BannedPhrase> marketingWordBans = [
  for (final word in const [
    'seamless',
    'effortless',
    'powerful',
    'blazing',
    'robust',
    'simply',
    'supercharge',
    'delightful',
    'magic',
    'revolutionary',
  ])
    marketingWord(word),
];

/// "just" used to make a step sound smaller than it is, as in "just call".
///
/// Only that sense is banned, so the ban needs a verb behind the word. The
/// tutorial's "What just happened" and a plain "not just loopback" are fine,
/// and a bare `\bjust\b` would report both.
final BannedPhrase belittlingJust = BannedPhrase(
  label: '"just" in front of a verb',
  pattern: RegExp(
    r'\bjust\s+(add|call|create|declare|define|drop|import|make|open|pass|'
    r'point|put|register|return|run|set|tell|use|wrap|write)\b',
    caseSensitive: false,
  ),
  instead: 'say what the step does',
);

/// A heading written as a question.
///
/// "What is Beak?" and "Why Beak?" are frozen nav titles the style guide
/// exempts by name, so the pattern looks past those two.
final BannedPhrase questionHeading = BannedPhrase(
  label: 'a heading written as a question',
  pattern: RegExp(r'^\s{0,3}#{1,6}\s+(?!(What is|Why) Beak\?\s*$).*\?\s*$'),
  instead: 'write "What a column is", not "What is a column?"',
);

/// Two or more exclamation points on one line of prose.
///
/// The style guide bans the storm, not the single mark, and [proseOf] has
/// already dropped the `!!!` admonition markers and the `![image]` syntax.
final BannedPhrase exclamationStorm = BannedPhrase(
  label: 'an exclamation-point storm',
  pattern: RegExp(r'![^!]*!'),
  instead: 'state what it does; the reader decides how they feel',
);

/// The em-dash, banned outright by the style guide.
///
/// Scoped to prose because Beak's own Dart doc comments are full of them, so
/// every fence that quotes real source carries one and has to keep it.
final BannedPhrase emDash = BannedPhrase(
  label: 'the em-dash',
  pattern: RegExp('—'),
  instead: 'a period, a comma, a colon, or parentheses',
);

/// The word "UseCase", which names a layer Beak's frontend does not have.
///
/// Spelled as one word, so the ordinary English "a use case for exports" is
/// left alone.
final BannedPhrase useCaseLayer = BannedPhrase(
  label: 'the word "UseCase"',
  pattern: RegExp(r'\bUseCases?\b'),
  instead: 'name the Repository or the ViewModel',
);

/// "unlock" in the marketing sense, as in "unlock the power of your data".
final BannedPhrase marketingUnlock = BannedPhrase(
  label: '"unlock"',
  pattern: RegExp(r'\bunlock\w*', caseSensitive: false),
  instead: 'state what it does and show the code',
);

/// Every ban that fails the run.
final List<BannedPhrase> enforcedBans = [
  ...marketingWordBans,
  belittlingJust,
  questionHeading,
  exclamationStorm,
  emDash,
];

/// Bans that are implemented and tested but only reported, never fatal.
///
/// Each one fires on published pages today, so enforcing it now would leave
/// the gate red for everybody. They are printed on every run instead. Once a
/// ban's lines below are gone, move it into [enforcedBans]:
///
/// * [useCaseLayer] hits the lines in `concepts/the-four-layers.md` that teach
///   the invariant by naming it. Enforcing it needs a way to say "this page
///   may name the thing it bans", which no other ban wants yet.
/// * [marketingUnlock] collides with the panel's lock screen, whose prose has
///   to be able to say "the unlock password" for `onUnlock`. Enforcing it
///   needs the marketing sense told apart from the API one.
final List<BannedPhrase> pendingBans = [useCaseLayer, marketingUnlock];

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

/// Reads the repository file at [path], or `null` when it is not there.
///
/// Injected into the checks so a test can hand them a page and the sources it
/// quotes without writing either to disk.
String? readRepoFile(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

void main() {
  final docs = Directory('docs');
  if (!docs.existsSync()) {
    stderr.writeln('No docs/ directory — run this from the repo root.');
    exit(2);
  }

  final problems = <DocProblem>[];
  final advisories = <DocProblem>[];
  for (final file in _publishedPages(docs)) {
    final String content = file.readAsStringSync();
    problems.addAll(checkPage(file.path, content));
    advisories.addAll(
      checkBannedPhrases(file.path, content.split('\n'), bans: pendingBans),
    );
  }

  _reportAdvisories(advisories);

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

/// Prints the [pendingBans] hits without failing the run.
///
/// They are listed on every run so the backlog stays visible and shrinks
/// instead of being rediscovered later.
void _reportAdvisories(List<DocProblem> advisories) {
  if (advisories.isEmpty) {
    return;
  }
  stdout.writeln(
    'Style-guide bans not enforced yet (${advisories.length} lines):',
  );
  for (final advisory in advisories) {
    stdout.writeln('  $advisory');
  }
  stdout.writeln(
    'Clear the lines for one of these, then move that ban from pendingBans to '
    'enforcedBans in tool/check_docs.dart.',
  );
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
/// Everything the page can be judged on alone is judged here. The two checks
/// that need the tree behind it, a fence title and a snippet include, go
/// through [readFile], which defaults to the repository as it is.
List<DocProblem> checkPage(
  String path,
  String content, {
  String? Function(String path) readFile = readRepoFile,
}) {
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
      } else if (_quotesRepo(named) && readFile(named) == null) {
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
      if (readFile(target) == null) {
        problems.add(
          DocProblem(
            path,
            'snippet includes "$target", which does not exist',
            line: number,
          ),
        );
      }
    }
  }

  problems.addAll(checkBannedPhrases(path, lines, bans: enforcedBans));
  problems.addAll(checkQuotations(path, lines, readFile: readFile));
  return problems;
}

/// Whether [path] names a file this repository is expected to contain.
bool _quotesRepo(String path) =>
    path.startsWith('packages/') ||
    path.startsWith('examples/') ||
    path.startsWith('tool/');

/// The lines of [lines] on [path] that break one of [bans].
///
/// Only prose is looked at. Fenced lines are the source being quoted, and
/// [proseOf] drops what is quoted inline, so a ban never asks a writer to
/// misquote the code to satisfy it.
List<DocProblem> checkBannedPhrases(
  String path,
  List<String> lines, {
  required List<BannedPhrase> bans,
}) {
  final problems = <DocProblem>[];
  final Set<int> fenced = fencedLineIndices(lines);
  for (var index = 0; index < lines.length; index += 1) {
    if (fenced.contains(index)) {
      continue;
    }
    final String prose = proseOf(lines[index]);
    for (final ban in bans) {
      if (ban.pattern.hasMatch(prose)) {
        problems.add(DocProblem(path, ban.message, line: index + 1));
      }
    }
  }
  return problems;
}

/// The 0-based indices of [lines] that sit inside a fenced code block.
///
/// The fence markers themselves are left out: an opener carries the
/// `title="..."` other checks read. A closing fence has to be at least as long
/// as the one it closes and carry no language, which is what keeps a
/// ````` ```` ````` block quoting a fenced example from ending early.
Set<int> fencedLineIndices(List<String> lines) {
  final fenced = <int>{};
  final marker = RegExp(r'^\s*(`{3,})(.*)$');
  String? open;
  for (var index = 0; index < lines.length; index += 1) {
    final RegExpMatch? match = marker.firstMatch(lines[index]);
    if (open == null) {
      if (match != null) {
        open = match.group(1);
      }
      continue;
    }
    final bool closes =
        match != null &&
        match.group(1)!.length >= open.length &&
        match.group(2)!.trim().isEmpty;
    if (closes) {
      open = null;
      continue;
    }
    fenced.add(index);
  }
  return fenced;
}

/// [line] reduced to the prose the writer chose.
///
/// Inline code spans go, because a banned word inside backticks is a symbol
/// (`onUnlock`) and an em-dash inside them is quoted source. The `!!!`/`???`
/// admonition markers and the `!` of an image link go too, so neither counts
/// towards an exclamation-point storm.
String proseOf(String line) => line
    .replaceAll(RegExp('`+[^`]*`+'), ' ')
    .replaceFirstMapped(RegExp(r'^(\s*)[!?]{3}\+?'), (match) => match.group(1)!)
    .replaceAll('![', '[');

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
List<DocProblem> checkQuotations(
  String path,
  List<String> lines, {
  String? Function(String path) readFile = readRepoFile,
}) {
  final problems = <DocProblem>[];
  for (final quotation in _quotationsIn(lines)) {
    final String? contents = readFile(quotation.target);
    if (contents == null) {
      // Already reported as a missing path.
      continue;
    }
    final List<String> source = _significant(contents.split('\n'));
    for (final chunk in chunksOf(quotation.body)) {
      if (containsRun(source, chunk)) {
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
    if (_quotesRepo(target) && !transcriptLanguages.contains(language)) {
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
List<List<String>> chunksOf(List<String> body) {
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
bool containsRun(List<String> source, List<String> run) {
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
