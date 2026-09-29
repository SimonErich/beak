/// Structural checks for the documentation (`melos run check-docs`).
///
/// MkDocs' `--strict` catches broken links and pages missing from the nav.
/// It cannot catch the things this file checks: a code fence claiming to
/// quote a file that no longer exists, a page with no front matter, a snippet
/// include pointing at a moved file or a deleted section marker, or a banned
/// phrase from the style guide.
///
/// The style guide's "Banned" section is enforced from [enforcedBans]. A ban
/// that a page must be able to break, because naming the thing is that page's
/// subject, lists it in [BannedPhrase.exceptPaths].
///
/// The information architecture is enforced too: every page declares a `type`,
/// an `audience` and a `status`, a nav label equals its page title, every nav
/// section opens on an index page that routes to all of its children, and
/// every path the site has ever served is still a page or a redirect. A page
/// marked `status: stable` must also carry the headings its `type` promises.
///
/// `--release` adds the completeness ratchet: it fails while any page is still
/// `status: draft`. The release workflow runs it; day-to-day runs do not.
///
/// Run from the repo root. Exits non-zero with one line per problem.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

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

/// A `--8<-- "path"` line: mkdocs reads that file in at build time.
///
/// The quoted form is the only one the docs use, so the pattern insists on
/// it rather than also matching the multi-line block form.
final RegExp snippetInclude = RegExp(r'^\s*--8<--\s+"([^"]+)"\s*$');

/// A `--8<-- [start:name]` or `[end:name]` marker in a quoted source file.
///
/// mkdocs strips these when it reads a section in, so they are build
/// metadata rather than code, and neither the reader nor a quotation of the
/// surrounding lines ever sees them.
final RegExp snippetMarker = RegExp(
  r'--8<--\s*\[\s*(start|end)\s*:\s*([\w-]+)\s*\]',
);

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
    this.exceptPaths = const {},
  });

  /// What is banned, phrased the way the style guide phrases it.
  final String label;

  /// Matches an occurrence of [label] in a line of prose.
  final RegExp pattern;

  /// What to write instead.
  final String instead;

  /// Pages allowed to name this, because naming it is their subject.
  ///
  /// A page that teaches "there is no UseCase layer" has to be able to write
  /// the words. Without this the choice is a ban that fires on the one page
  /// stating the rule, or no ban at all.
  final Set<String> exceptPaths;

  /// Whether this ban applies to the page at [path].
  bool appliesTo(String path) => !exceptPaths.contains(path);

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
  // The two pages that state the invariant have to be able to name what they
  // forbid. Everywhere else the word means someone has the architecture wrong.
  exceptPaths: {
    'docs/concepts/the-four-layers.md',
    'docs/contributing/code-guardrails.md',
  },
);

/// "unlock" in the marketing sense, as in "unlock the power of your data".
///
/// Scoped to that sense rather than to the word: the panel has a lock screen
/// with an `onUnlock` callback and an unlock password, so a bare `\bunlock`
/// fires on the page documenting them and on nothing else.
final BannedPhrase marketingUnlock = BannedPhrase(
  label: '"unlock" in the marketing sense',
  pattern: RegExp(
    r'\bunlock\w*\s+(the\s+|its\s+|your\s+)?'
    r'(power|potential|value|magic|full|true|hidden|insights?)\b',
    caseSensitive: false,
  ),
  instead: 'state what it does and show the code',
);

/// Every ban that fails the run.
final List<BannedPhrase> enforcedBans = [
  ...marketingWordBans,
  belittlingJust,
  questionHeading,
  exclamationStorm,
  emDash,
  useCaseLayer,
  marketingUnlock,
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

/// Reads the repository file at [path], or `null` when it is not there.
///
/// Injected into the checks so a test can hand them a page and the sources it
/// quotes without writing either to disk.
String? readRepoFile(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

void main(List<String> args) {
  final docs = Directory('docs');
  if (!docs.existsSync()) {
    stderr.writeln('No docs/ directory — run this from the repo root.');
    exit(2);
  }

  final contents = <String, String>{
    for (final file in _publishedPages(docs))
      file.path: file.readAsStringSync(),
  };
  final problems = <DocProblem>[];
  for (final entry in contents.entries) {
    problems
      ..addAll(checkPage(entry.key, entry.value))
      ..addAll(checkPageMetadata(entry.key, entry.value));
  }
  problems.addAll(
    checkSite(
      pages: contents,
      mkdocsYaml: readRepoFile('mkdocs.yml'),
      manifest: readRepoFile(urlManifestPath),
      release: args.contains('--release'),
    ),
  );

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

    final RegExpMatch? include = snippetInclude.firstMatch(line);
    if (include != null) {
      problems.addAll(
        checkInclude(path, include.group(1)!, number, readFile: readFile),
      );
    }
  }

  problems.addAll(checkBannedPhrases(path, lines, bans: enforcedBans));
  problems.addAll(checkQuotations(path, lines, readFile: readFile));
  return problems;
}

/// The problems in the snippet include of [reference], on line [line] of
/// [path].
///
/// An include cannot drift the way a copy does, because mkdocs re-reads the
/// file on every build. It can still rot, and quietly: rename the symbol and
/// the markers go with it, and the page publishes an empty block. Drop only
/// the end marker and the section runs to the end of the file. So the file
/// has to be there, and a named section needs both of its markers.
List<DocProblem> checkInclude(
  String path,
  String reference,
  int line, {
  String? Function(String path) readFile = readRepoFile,
}) {
  final String target = reference.split(':').first;
  final String? contents = readFile(target);
  if (contents == null) {
    return [
      DocProblem(
        path,
        'snippet includes "$target", which does not exist',
        line: line,
      ),
    ];
  }
  final String? section = sectionOf(reference);
  if (section == null) {
    return const [];
  }
  final List<({String kind, int at})> markers = [
    for (final match in snippetMarker.allMatches(contents))
      if (match.group(2)! == section) (kind: match.group(1)!, at: match.start),
  ];
  final Set<String> kinds = {for (final marker in markers) marker.kind};
  if (!kinds.contains('start')) {
    return [
      DocProblem(
        path,
        'snippet includes section "$section" of "$target", which has no '
        '"--8<-- [start:$section]" marker. Restore the markers around the '
        'symbol, or point the include at what replaced it.',
        line: line,
      ),
    ];
  }
  if (!kinds.contains('end')) {
    return [
      DocProblem(
        path,
        'snippet includes section "$section" of "$target", which opens the '
        'section but never closes it, so the include runs to the end of the '
        'file. Add "--8<-- [end:$section]".',
        line: line,
      ),
    ];
  }
  final int start = markers.firstWhere((marker) => marker.kind == 'start').at;
  final int end = markers.firstWhere((marker) => marker.kind == 'end').at;
  if (end < start) {
    return [
      DocProblem(
        path,
        'snippet includes section "$section" of "$target", whose "end" marker '
        'sits above its "start". Both are present, so the include is not '
        'reported as broken; it just publishes nothing.',
        line: line,
      ),
    ];
  }
  return const [];
}

/// The section [reference] names, or `null` when it reads a whole file.
///
/// pymdownx also accepts a line range (`file.dart:12:20`), which has no
/// marker to look for, so a tail that is not a section name is not one.
String? sectionOf(String reference) {
  final int separator = reference.indexOf(':');
  if (separator == -1) {
    return null;
  }
  final String tail = reference.substring(separator + 1);
  // A leading underscore is allowed: mkdocs does not care, and misreading
  // `file.dart:_helper` as a whole-file include would skip the marker check
  // on exactly the sections nothing else is watching.
  return RegExp(r'^[A-Za-z_][\w-]*$').hasMatch(tail) ? tail : null;
}

/// Root-level files this repository owns and pages quote verbatim.
///
/// Listed rather than inferred from what happens to exist, for two reasons.
/// A fence titled `beak.yaml` or `lib/models/product.dart` names a file in
/// the *reader's* project. And a path that exists in a working copy is not
/// the same as one a clone has: `PLAN/` is git-ignored, so inferring from
/// disk would pass here and fail in CI.
const Set<String> quotableRootFiles = {
  'melos.yaml',
  'mkdocs.yml',
  'pubspec.yaml',
  'analysis_options.yaml',
  'docker-compose.yml',
  'CONTRIBUTING.md',
  'README.md',
};

/// Whether [path] names a file this repository is expected to contain.
bool _quotesRepo(String path) =>
    path.startsWith('packages/') ||
    path.startsWith('examples/') ||
    path.startsWith('tool/') ||
    path.startsWith('deploy/') ||
    quotableRootFiles.contains(path);

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
      if (ban.appliesTo(path) && ban.pattern.hasMatch(prose)) {
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
///
/// A fence whose body is a `--8<--` include is not a quotation and is left
/// out: mkdocs substitutes the file at build time, so there is nothing on the
/// page to compare. [checkInclude] is what guards those.
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
    final List<String> body = lines.sublist(index + 1, close);
    if (_quotesRepo(target) &&
        !transcriptLanguages.contains(language) &&
        !isIncludeBody(body)) {
      yield _Quotation(target: target, line: index + 1, body: body);
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

/// Whether [body] is a snippet include rather than a copy of the source.
///
/// One include line and nothing else. A fence that mixes an include with
/// lines someone typed is still partly a copy, so it stays a quotation.
bool isIncludeBody(List<String> body) {
  final List<String> significant = _significant(body);
  return significant.length == 1 && snippetInclude.hasMatch(significant.single);
}

/// [lines] reduced to what a comparison should care about: trimmed, with
/// blank lines and snippet section markers dropped.
///
/// The markers go because mkdocs strips them too. A page quoting lines that
/// straddle one is quoting the code the reader will see, so it must not have
/// to paste a build directive in to stay faithful.
List<String> _significant(List<String> lines) => [
  for (final line in lines)
    if (line.trim().isNotEmpty && !snippetMarker.hasMatch(line)) line.trim(),
];

/// [body] split on elision markers into the runs that must each appear.
///
/// A one-line run *between elisions* is skipped: a line lifted out of its
/// surroundings is as likely to be a paraphrase of a signature as a quotation
/// of one, and reporting it would cost more than it catches.
///
/// A body that is one line and elides nothing is not that. It claims to be
/// the whole of what it quotes, so it is checked like any other run. It used
/// to be skipped under the same rule, and a fence quoting
/// `BeakAlertBlock('Saved', ...)` sat there having dropped the `const` its
/// source carries.
List<List<String>> chunksOf(List<String> body) {
  final List<String> lines = _significant(body);
  final bool elides = lines.any(elisionMarker.hasMatch);
  final int shortest = elides ? 2 : 1;

  final chunks = <List<String>>[];
  var current = <String>[];
  for (final line in lines) {
    if (elisionMarker.hasMatch(line)) {
      if (current.length >= shortest) {
        chunks.add(current);
      }
      current = <String>[];
      continue;
    }
    current.add(line);
  }
  if (current.length >= shortest) {
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

/// Where the URL manifest lives: every path the site has ever served.
const String urlManifestPath = 'docs/_internal/url-manifest.txt';

/// The values a page's `type` may take.
const Set<String> pageTypes = {
  'index',
  'tutorial',
  'guide',
  'concept',
  'reference',
  'recipe',
  'example',
  'ai',
};

/// The values an entry of a page's `audience` may take.
const Set<String> pageAudiences = {
  'beginner',
  'expert',
  'agent',
  'contributor',
};

/// The values a page's `status` may take.
///
/// A `draft` page is a stub or awaits its rewrite, `preview` documents
/// something that has not shipped, and only `stable` promises the headings of
/// its `type`.
const Set<String> pageStatuses = {'stable', 'draft', 'preview'};

/// The status `--release` refuses.
const String draftStatus = 'draft';

/// The longest description a search result can show.
const int maxDescriptionLengthInCharacters = 160;

/// The heading every section index carries above its routing table.
const String routingHeading = '## Which page to read';

/// The headings a `status: stable` page of each `type` must carry.
///
/// The page templates in the docs style guide are the source: an opener, then
/// these sections, then "Continue reading" (which every page needs already).
const Map<String, List<String>> requiredHeadings = {
  'index': [routingHeading],
  'tutorial': [
    "## What you'll build",
    '## Before you start',
    '## Run it',
    '## Checkpoint',
  ],
  'guide': [
    '## At a glance',
    '## Rules and limits',
    '## Verify it',
    '## Reference',
  ],
  'concept': [
    '## The idea in one picture',
    '## How it works',
    '## Why it is shaped this way',
    '## What it means for you',
  ],
  'reference': ['## Import', '## Summary', '## Source'],
  'recipe': ['## Recipe', '## How it works', '## Variations', '## Verify'],
  'example': [
    '## At a glance',
    '## Run it',
    '## Tour',
    '## Where things are',
    '## Features shown',
    '## Tests',
    '## Limits',
  ],
  'ai': ['## Rules', '## Machine-readable twin'],
};

/// A page's front matter, as far as the site checks read it.
final class FrontMatter {
  /// Front matter with the fields YAML gave, or with [error] when it did not
  /// parse.
  const FrontMatter({
    this.title,
    this.description,
    this.type,
    this.audience = const [],
    this.status,
    this.error,
  });

  /// The `title`, or `null` when absent or not a string.
  final String? title;

  /// The `description`, or `null` when absent or not a string.
  final String? description;

  /// The `type`, or `null` when absent or not a string.
  final String? type;

  /// The `audience` entries; empty when absent or not a list of strings.
  final List<String> audience;

  /// The `status`, or `null` when absent or not a string.
  final String? status;

  /// Why YAML rejected the block, or `null` when it parsed.
  final String? error;
}

/// The front matter of [content], or `null` when the page has none.
FrontMatter? parseFrontMatter(String content) {
  if (!content.startsWith('---\n')) {
    return null;
  }
  final List<String> lines = content.split('\n');
  final int end = lines.indexOf('---', 1);
  if (end == -1) {
    return const FrontMatter(error: 'the block is never closed');
  }
  final Object? node;
  try {
    node = loadYaml(lines.sublist(1, end).join('\n'));
  } on YamlException catch (exception) {
    return FrontMatter(error: exception.message);
  }
  if (node is! YamlMap) {
    return const FrontMatter(error: 'the block is not a mapping');
  }
  final Object? audience = node['audience'];
  return FrontMatter(
    title: _stringOf(node['title']),
    description: _stringOf(node['description']),
    type: _stringOf(node['type']),
    audience: audience is YamlList
        ? [for (final Object? entry in audience) ?_stringOf(entry)]
        : const [],
    status: _stringOf(node['status']),
  );
}

/// [value] when it is a string.
String? _stringOf(Object? value) => value is String ? value : null;

/// Whether the repository has a file or directory at [path].
bool repoPathExists(String path) =>
    File(path).existsSync() || Directory(path).existsSync();

/// A backticked repository path in prose: `packages/...`, `examples/...`,
/// `tool/...` or `deploy/...`, and nothing else inside the backticks.
final RegExp _repoPathSpan = RegExp(
  r'`((?:packages|examples|tool|deploy)/[A-Za-z0-9_./-]+)`',
);

/// The problems in the metadata of the page at [path] with [content].
///
/// Checks the fields the information architecture depends on (`type`,
/// `audience`, `status`), that the H1 matches the title, that a `stable` page
/// carries the headings its type promises, and that every repository path the
/// prose names in backticks exists. A page with no front matter is left to
/// [checkPage], which reports it.
List<DocProblem> checkPageMetadata(
  String path,
  String content, {
  bool Function(String path) pathExists = repoPathExists,
}) {
  final FrontMatter? front = parseFrontMatter(content);
  if (front == null) {
    return const [];
  }
  final String? error = front.error;
  if (error != null) {
    return [DocProblem(path, 'front matter is not valid YAML: $error')];
  }

  final problems = <DocProblem>[];
  final String? type = front.type;
  if (type == null) {
    problems.add(
      DocProblem(path, 'front matter has no "type:" (${pageTypes.join('|')})'),
    );
  } else if (!pageTypes.contains(type)) {
    problems.add(
      DocProblem(
        path,
        'front matter type "$type" is not one of ${pageTypes.join('|')}',
      ),
    );
  }
  if (front.audience.isEmpty) {
    problems.add(
      DocProblem(
        path,
        'front matter has no "audience:" list '
        '(${pageAudiences.join('|')})',
      ),
    );
  }
  for (final audience in front.audience) {
    if (!pageAudiences.contains(audience)) {
      problems.add(
        DocProblem(
          path,
          'front matter audience "$audience" is not one of '
          '${pageAudiences.join('|')}',
        ),
      );
    }
  }
  final String? status = front.status;
  if (status == null) {
    problems.add(
      DocProblem(
        path,
        'front matter has no "status:" (${pageStatuses.join('|')})',
      ),
    );
  } else if (!pageStatuses.contains(status)) {
    problems.add(
      DocProblem(
        path,
        'front matter status "$status" is not one of '
        '${pageStatuses.join('|')}',
      ),
    );
  }
  final String? description = front.description;
  if (description != null &&
      description.length > maxDescriptionLengthInCharacters) {
    problems.add(
      DocProblem(
        path,
        'description is ${description.length} characters; a search result '
        'shows $maxDescriptionLengthInCharacters',
      ),
    );
  }

  final List<String> lines = content.split('\n');
  final Set<int> fenced = fencedLineIndices(lines);
  final int bodyStart = lines.indexOf('---', 1) + 1;
  final String? title = front.title;
  for (var index = bodyStart; index < lines.length; index += 1) {
    if (fenced.contains(index) || !lines[index].startsWith('# ')) {
      continue;
    }
    final String heading = lines[index].substring(2).trim();
    if (title != null && heading != title) {
      problems.add(
        DocProblem(
          path,
          'the H1 "$heading" differs from the title "$title"',
          line: index + 1,
        ),
      );
    }
    break;
  }

  if (status == 'stable' && type != null && requiredHeadings[type] != null) {
    final Set<String> headings = {
      for (var index = bodyStart; index < lines.length; index += 1)
        if (!fenced.contains(index)) lines[index].trimRight(),
    };
    for (final heading in requiredHeadings[type]!) {
      if (!headings.contains(heading)) {
        problems.add(
          DocProblem(
            path,
            'status is stable, but a page of type "$type" needs the heading '
            '"$heading". Add it, or mark the page "status: draft"',
          ),
        );
      }
    }
  }

  for (var index = bodyStart; index < lines.length; index += 1) {
    if (fenced.contains(index)) {
      continue;
    }
    for (final match in _repoPathSpan.allMatches(lines[index])) {
      final String named = match.group(1)!;
      final String target = named.endsWith('/')
          ? named.substring(0, named.length - 1)
          : named;
      if (!target.contains('..') && !pathExists(target)) {
        problems.add(
          DocProblem(
            path,
            'names `$named`, which does not exist',
            line: index + 1,
          ),
        );
      }
    }
  }
  return problems;
}

/// A published page as the site-level checks read it.
final class SitePage {
  /// The page at repository [path] (`docs/...`) holding [content].
  SitePage(this.path, this.content)
    : docPath = path.startsWith('docs/') ? path.substring(5) : path,
      front = parseFrontMatter(content);

  /// The repository path, `docs/...`.
  final String path;

  /// The path relative to `docs/`, the form the nav and redirects use.
  final String docPath;

  /// The page's Markdown, front matter included.
  final String content;

  /// The parsed front matter, or `null` when the page has none.
  final FrontMatter? front;

  /// The page title, or `null` when the front matter has none.
  String? get title => front?.title;
}

/// One entry of the `nav:` tree.
sealed class NavNode {
  /// An entry with the label the reader sees, or `null` for a bare path,
  /// whose label mkdocs takes from the page title.
  const NavNode(this.label);

  /// The label written in `mkdocs.yml`, if any.
  final String? label;
}

/// A nav entry that is a page.
final class NavPage extends NavNode {
  /// A page at [path] (relative to `docs/`).
  const NavPage(super.label, this.path);

  /// The page path relative to `docs/`.
  final String path;
}

/// A nav entry that groups other entries.
final class NavSection extends NavNode {
  /// A section named [label] holding [children].
  const NavSection(String super.label, this.children);

  /// The section's entries, in order.
  final List<NavNode> children;
}

/// The text of the top-level [key] block of [yaml], or `null` when it has none.
///
/// `mkdocs.yml` carries `!!python/name` tags that only Python can construct, so
/// the file as a whole cannot be parsed here. The `nav:` and `plugins:` blocks
/// carry none, and this cuts them out by their indentation.
String? topLevelBlock(String yaml, String key) {
  final List<String> lines = yaml.split('\n');
  final int start = lines.indexWhere((line) => line.startsWith('$key:'));
  if (start == -1) {
    return null;
  }
  var end = start + 1;
  while (end < lines.length) {
    final String line = lines[end];
    final bool continues =
        line.isEmpty ||
        line.startsWith(' ') ||
        line.startsWith('#') ||
        line.startsWith('-');
    if (!continues) {
      break;
    }
    end += 1;
  }
  return lines.sublist(start, end).join('\n');
}

/// The nav tree in the `nav:` [block] of `mkdocs.yml`.
List<NavNode> parseNav(String block) {
  final Object? root = loadYaml(block);
  if (root is YamlMap) {
    return _navEntries(root['nav']);
  }
  return const [];
}

List<NavNode> _navEntries(Object? node) {
  if (node is! YamlList) {
    return const [];
  }
  final entries = <NavNode>[];
  for (final Object? item in node) {
    if (item is String) {
      entries.add(NavPage(null, item));
    } else if (item is YamlMap && item.length == 1) {
      final entry = item.entries.single;
      final String label = '${entry.key}';
      final Object? value = entry.value;
      if (value is String) {
        entries.add(NavPage(label, value));
      } else if (value is YamlList) {
        entries.add(NavSection(label, _navEntries(value)));
      }
    }
  }
  return entries;
}

/// The path segments of [target] resolved against the page at [fromDocPath].
String _resolveLink(String fromDocPath, String target) {
  final segments = <String>[
    ...fromDocPath.split('/').reversed.skip(1).toList().reversed,
  ];
  for (final segment in target.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

/// The pages [page] links to in prose, as paths relative to `docs/`.
Set<String> linkedPages(SitePage page) {
  final List<String> lines = page.content.split('\n');
  final Set<int> fenced = fencedLineIndices(lines);
  final linked = <String>{};
  for (var index = 0; index < lines.length; index += 1) {
    if (fenced.contains(index)) {
      continue;
    }
    for (final match in RegExp(r'\]\(([^)\s]+)').allMatches(lines[index])) {
      final String written = match.group(1)!;
      final int hash = written.indexOf('#');
      final String target = hash == -1 ? written : written.substring(0, hash);
      if (target.isEmpty || target.contains(':') || target.startsWith('/')) {
        continue;
      }
      linked.add(_resolveLink(page.docPath, target));
    }
  }
  return linked;
}

/// The problems in the nav tree [nav] over the published [pages].
///
/// [pages] is keyed by path relative to `docs/`. A nav label must equal the
/// page title (the home page, which serves as the Start tab's index, is
/// exempt), and titles are unique across the site. Every section opens on an
/// `index.md` that carries [routingHeading] and links every other child; a
/// child section is linked through its own index. A published page missing
/// from the nav is reported too, before mkdocs would.
List<DocProblem> checkNavigation({
  required List<NavNode> nav,
  required Map<String, SitePage> pages,
}) {
  final problems = <DocProblem>[];
  final navPaths = <String>{};
  final titleOwners = <String, List<String>>{};

  void visit(List<NavNode> nodes) {
    for (final node in nodes) {
      switch (node) {
        case NavPage(:final label, :final path):
          navPaths.add(path);
          final SitePage? page = pages[path];
          if (page == null) {
            problems.add(
              DocProblem(
                'mkdocs.yml',
                'the nav lists "$path", which is not a page',
              ),
            );
            break;
          }
          final String? title = page.title;
          if (title != null) {
            titleOwners.putIfAbsent(title, () => []).add(path);
          }
          if (label != null && title != null && label != title) {
            problems.add(
              DocProblem(
                'mkdocs.yml',
                'the nav label "$label" differs from the title "$title" of '
                    '"$path"',
              ),
            );
          }
        case NavSection(:final children):
          problems.addAll(_checkSection(node, pages));
          visit(children);
      }
    }
  }

  visit(nav);

  for (final owners in titleOwners.entries) {
    if (owners.value.length > 1) {
      problems.add(
        DocProblem(
          'mkdocs.yml',
          'the title "${owners.key}" belongs to ${owners.value.join(' and ')}; '
              'titles are unique across the site',
        ),
      );
    }
  }
  for (final page in pages.values) {
    if (!navPaths.contains(page.docPath)) {
      problems.add(DocProblem(page.path, 'is not in the nav'));
    }
  }
  return problems;
}

/// Whether [path] is an `index.md` page.
bool _isIndexPath(String path) => path.split('/').last == 'index.md';

/// The problems in one nav [section]: its index page and the routing table.
List<DocProblem> _checkSection(
  NavSection section,
  Map<String, SitePage> pages,
) {
  final String label = section.label!;
  final NavNode? first = section.children.isEmpty
      ? null
      : section.children.first;
  if (first is! NavPage || !_isIndexPath(first.path)) {
    return [
      DocProblem(
        'mkdocs.yml',
        'the section "$label" does not open on an index.md page',
      ),
    ];
  }
  final SitePage? index = pages[first.path];
  if (index == null) {
    return const [];
  }
  final problems = <DocProblem>[];
  final String? title = index.title;
  if (first.path != 'index.md' && title != null && title != label) {
    problems.add(
      DocProblem(
        'mkdocs.yml',
        'the section label "$label" differs from the title "$title" of its '
            'index "${first.path}"',
      ),
    );
  }
  final List<String> lines = index.content.split('\n');
  final Set<int> fenced = fencedLineIndices(lines);
  final bool hasRouting = [
    for (var i = 0; i < lines.length; i += 1)
      if (!fenced.contains(i)) lines[i].trimRight(),
  ].contains(routingHeading);
  if (!hasRouting) {
    problems.add(
      DocProblem(
        index.path,
        'the index of "$label" has no "$routingHeading" section',
      ),
    );
  }
  final Set<String> linked = linkedPages(index);
  for (final child in section.children.skip(1)) {
    final String? target = switch (child) {
      NavPage(:final path) => path,
      NavSection(children: [NavPage(:final path), ...])
          when _isIndexPath(path) =>
        path,
      NavSection() => null,
    };
    if (target != null && !linked.contains(target)) {
      problems.add(
        DocProblem(
          index.path,
          'the index of "$label" does not link "$target" under '
          '"$routingHeading"',
        ),
      );
    }
  }
  return problems;
}

/// The `redirect_maps` of the `redirects` plugin in a `plugins:` [block].
Map<String, String> parseRedirects(String block) {
  final redirects = <String, String>{};
  final Object? root = loadYaml(block);
  final Object? plugins = root is YamlMap ? root['plugins'] : null;
  if (plugins is! YamlList) {
    return redirects;
  }
  for (final Object? plugin in plugins) {
    if (plugin is! YamlMap) {
      continue;
    }
    final Object? config = plugin['redirects'];
    final Object? maps = config is YamlMap ? config['redirect_maps'] : null;
    if (maps is YamlMap) {
      for (final entry in maps.entries) {
        redirects['${entry.key}'] = '${entry.value}';
      }
    }
  }
  return redirects;
}

/// The path globs the `llmstxt` plugin lists in a `plugins:` [block], or
/// `null` when the plugin is not configured.
List<String>? parseLlmsGlobs(String block) {
  final Object? root = loadYaml(block);
  final Object? plugins = root is YamlMap ? root['plugins'] : null;
  if (plugins is! YamlList) {
    return null;
  }
  for (final Object? plugin in plugins) {
    if (plugin is! YamlMap || !plugin.containsKey('llmstxt')) {
      continue;
    }
    final Object? config = plugin['llmstxt'];
    final Object? sections = config is YamlMap ? config['sections'] : null;
    final globs = <String>[];
    if (sections is YamlMap) {
      for (final Object? entries in sections.values) {
        if (entries is! YamlList) {
          continue;
        }
        for (final Object? entry in entries) {
          if (entry is String) {
            globs.add(entry);
          } else if (entry is YamlMap && entry.length == 1) {
            globs.add('${entry.keys.single}');
          }
        }
      }
    }
    return globs;
  }
  return null;
}

/// The problems between the URL [manifest] entries, the published [pagePaths]
/// and the [redirects].
///
/// Every path the site has ever served has to be a page or a redirect key, or
/// a bookmark to it breaks. Every redirect has to land on a page, and a
/// redirect key that is also a page is shadowed by the page.
List<DocProblem> checkManifest({
  required List<String> manifest,
  required Set<String> pagePaths,
  required Map<String, String> redirects,
}) {
  final problems = <DocProblem>[];
  for (final entry in manifest) {
    if (!pagePaths.contains(entry) && !redirects.containsKey(entry)) {
      problems.add(
        DocProblem(
          urlManifestPath,
          '"$entry" was published, but is neither a page nor a redirect. Add '
          'a redirect_maps entry for it in mkdocs.yml',
        ),
      );
    }
  }
  for (final redirect in redirects.entries) {
    final String target = redirect.value.split('#').first;
    if (!pagePaths.contains(target)) {
      problems.add(
        DocProblem(
          'mkdocs.yml',
          'the redirect "${redirect.key}" points at "$target", which is not a '
              'page',
        ),
      );
    }
    if (pagePaths.contains(redirect.key)) {
      problems.add(
        DocProblem(
          'mkdocs.yml',
          'the redirect "${redirect.key}" is also a page, so the page shadows '
              'it',
        ),
      );
    }
  }
  return problems;
}

/// The problems between the `llmstxt` [globs] and the published [pagePaths].
///
/// The plugin lists pages by glob, and `*` there crosses directories. A page
/// no glob matches is missing from `/llms.txt`, and a glob that matches no
/// page is a typo.
List<DocProblem> checkLlmsGlobs({
  required List<String> globs,
  required Set<String> pagePaths,
}) {
  final problems = <DocProblem>[];
  final matchers = <String, RegExp>{
    for (final glob in globs)
      glob: RegExp('^${glob.split('*').map(RegExp.escape).join('.*')}\$'),
  };
  for (final matcher in matchers.entries) {
    if (!pagePaths.any(matcher.value.hasMatch)) {
      problems.add(
        DocProblem(
          'mkdocs.yml',
          'the llmstxt glob "${matcher.key}" matches no page',
        ),
      );
    }
  }
  for (final page in pagePaths) {
    if (!matchers.values.any((matcher) => matcher.hasMatch(page))) {
      problems.add(
        DocProblem(
          'docs/$page',
          'is in no llmstxt section of mkdocs.yml, so /llms.txt omits it',
        ),
      );
    }
  }
  return problems;
}

/// The problems that need the whole site rather than one page.
///
/// [pages] maps a repository path (`docs/...`) to the page's Markdown.
/// [mkdocsYaml] is `mkdocs.yml` and [manifest] the URL manifest, each `null`
/// when the file is missing. With [release], a page that is still
/// `status: draft` is a problem: that is the completeness ratchet.
List<DocProblem> checkSite({
  required Map<String, String> pages,
  required String? mkdocsYaml,
  required String? manifest,
  bool release = false,
}) {
  final problems = <DocProblem>[];
  final byDocPath = <String, SitePage>{
    for (final entry in pages.entries)
      SitePage(entry.key, entry.value).docPath: SitePage(
        entry.key,
        entry.value,
      ),
  };

  if (release) {
    for (final page in byDocPath.values) {
      if (page.front?.status == draftStatus) {
        problems.add(
          DocProblem(
            page.path,
            'status is draft. A release needs every page stable or preview',
          ),
        );
      }
    }
  }

  if (mkdocsYaml == null) {
    return [...problems, const DocProblem('mkdocs.yml', 'is missing')];
  }
  final String? navBlock = topLevelBlock(mkdocsYaml, 'nav');
  final String? pluginsBlock = topLevelBlock(mkdocsYaml, 'plugins');
  if (navBlock == null || pluginsBlock == null) {
    return [
      ...problems,
      const DocProblem('mkdocs.yml', 'needs both a nav: and a plugins: block'),
    ];
  }
  try {
    problems.addAll(checkNavigation(nav: parseNav(navBlock), pages: byDocPath));
    final Map<String, String> redirects = parseRedirects(pluginsBlock);
    problems.addAll(
      checkManifest(
        manifest: manifest == null ? const [] : manifestEntries(manifest),
        pagePaths: byDocPath.keys.toSet(),
        redirects: redirects,
      ),
    );
    final List<String>? globs = parseLlmsGlobs(pluginsBlock);
    if (globs != null) {
      problems.addAll(
        checkLlmsGlobs(globs: globs, pagePaths: byDocPath.keys.toSet()),
      );
    }
  } on YamlException catch (exception) {
    problems.add(
      DocProblem(
        'mkdocs.yml',
        'nav or plugins is not valid YAML: '
            '${exception.message}',
      ),
    );
  }
  if (manifest == null) {
    problems.add(const DocProblem(urlManifestPath, 'is missing'));
  }
  return problems;
}

/// The path entries of a URL [manifest]: one per line, `#` lines ignored.
List<String> manifestEntries(String manifest) => [
  for (final line in manifest.split('\n'))
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) line.trim(),
];
