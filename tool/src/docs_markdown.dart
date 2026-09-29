/// Markdown-level rewrites the docs tools share.
///
/// The site is written for MkDocs Material: admonitions, content tabs,
/// `attr_list`, `md_in_html`, links between pages. `tool/build_agent_docs.dart`
/// turns a page into plain CommonMark an agent can read from a file, and
/// `tool/check_docs.dart` reads fences the same way, so the rules for what
/// counts as code live here once.
library;

/// A line that opens or closes a fenced code block: the fence, then the rest.
final RegExp fenceMarker = RegExp(r'^\s*(`{3,})(.*)$');

/// The 0-based indices of [lines] that sit inside a fenced code block.
///
/// The fence markers themselves are left out: an opener carries the
/// `title="..."` other checks read. A closing fence has to be at least as long
/// as the one it closes and carry no language, which is what keeps a
/// ````` ```` ````` block quoting a fenced example from ending early.
Set<int> fencedLineIndices(List<String> lines) {
  final fenced = <int>{};
  String? open;
  for (var index = 0; index < lines.length; index += 1) {
    final RegExpMatch? match = fenceMarker.firstMatch(lines[index]);
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

/// [line] with [transform] applied to everything outside inline code.
///
/// A code span is a run of backticks up to the next run of the same length.
/// A run that never closes is ordinary text.
String mapOutsideCode(String line, String Function(String text) transform) {
  final List<RegExpMatch> runs = RegExp('`+').allMatches(line).toList();
  final buffer = StringBuffer();
  var cursor = 0;
  var run = 0;
  while (run < runs.length) {
    final int width = runs[run].group(0)!.length;
    final int close = runs.indexWhere(
      (candidate) => candidate.group(0)!.length == width,
      run + 1,
    );
    if (close == -1) {
      run += 1;
      continue;
    }
    buffer
      ..write(transform(line.substring(cursor, runs[run].start)))
      ..write(line.substring(runs[run].start, runs[close].end));
    cursor = runs[close].end;
    run = close + 1;
  }
  buffer.write(transform(line.substring(cursor)));
  return buffer.toString();
}

/// One `attr_list` token: `.class`, `#id` or `key=value`.
const String _attributeToken =
    r'(?:[#.][\w-]+|[\w-]+=(?:"[^"]*"|'
    "'[^']*'"
    r'|[^\s}]+))';

/// An `attr_list` block: `{ .class #id key="value" }`, or `{: .class }`.
///
/// Only braces holding nothing but attribute tokens match, so a JSON example
/// or a Dart set literal in prose is never mistaken for one. The tokens are
/// styling for the site, so they are dropped, `#id` included.
final RegExp _attributeList = RegExp(
  r'\s*\{:?\s*'
  '$_attributeToken'
  r'(?:\s+'
  '$_attributeToken'
  r')*\s*\}',
);

/// [lines] without the `md_in_html` wrappers and `attr_list` blocks.
///
/// A wrapper is a `<div markdown>` (or any tag carrying a `markdown`
/// attribute) alone on its line, together with the closing tag that matches
/// it. Its content is already Markdown, so only the tags go. Fenced lines are
/// left alone.
List<String> stripSiteMarkup(List<String> lines) {
  final List<String> unwrapped = _dropWrappers(lines);
  final Set<int> fenced = fencedLineIndices(unwrapped);
  final result = <String>[];
  for (var index = 0; index < unwrapped.length; index += 1) {
    final String line = unwrapped[index];
    if (fenced.contains(index) || fenceMarker.hasMatch(line)) {
      result.add(line);
      continue;
    }
    final String stripped = mapOutsideCode(
      line,
      (text) => text.replaceAll(_attributeList, ''),
    );
    if (stripped.trim().isEmpty && line.trim().isNotEmpty) {
      continue;
    }
    result.add(stripped);
  }
  return result;
}

/// A tag alone on its line: its name, and whether it is a closing tag.
final RegExp _tagLine = RegExp(r'^\s*<(/?)([a-zA-Z][\w-]*)\b[^>]*?(/?)>\s*$');

/// The `markdown` attribute `md_in_html` looks for, bare or with a value.
final RegExp _markdownAttribute = RegExp(r'\smarkdown\b');

/// [lines] without the `markdown`-attribute wrappers and their closing tags.
List<String> _dropWrappers(List<String> lines) {
  final Set<int> fenced = fencedLineIndices(lines);
  final result = <String>[];
  final open = <({String tag, bool wrapper})>[];
  for (var index = 0; index < lines.length; index += 1) {
    final String line = lines[index];
    final RegExpMatch? tag = fenced.contains(index)
        ? null
        : _tagLine.firstMatch(line);
    if (tag == null || tag.group(3) == '/') {
      result.add(line);
      continue;
    }
    final String name = tag.group(2)!.toLowerCase();
    if (tag.group(1) == '/') {
      if (open.isNotEmpty && open.last.tag == name) {
        if (!open.removeLast().wrapper) {
          result.add(line);
        }
      } else {
        result.add(line);
      }
      continue;
    }
    final bool wrapper = _markdownAttribute.hasMatch(line);
    if (wrapper || open.isNotEmpty) {
      open.add((tag: name, wrapper: wrapper));
    }
    if (!wrapper) {
      result.add(line);
    }
  }
  return result;
}

/// An admonition or collapsible block opener: `!!! note "Title"`,
/// `??? tip`, `???+ warning "Title"`.
final RegExp _admonition = RegExp(
  r'^(\s*)(?:!!!|\?\?\?\+?)\s+([\w-]+)(?:\s+[\w-]+)*(?:\s+"(.*)")?\s*$',
);

/// A content tab opener: `=== "Label"`.
final RegExp _tab = RegExp(r'''^(\s*)===\+?\s+["'](.*)["']\s*$''');

/// [lines] with admonitions turned into blockquotes and content tabs into
/// bold labels.
///
/// `!!! note "Title"` and its indented body become `> **Note: Title**`, a
/// `>` line and the body quoted. `=== "Label"` becomes `**Label**` over the
/// body, dedented. Nesting works to any depth, and fenced code is never
/// interpreted: a fence inside a body stays a fence, quoted with the rest.
List<String> convertContainers(List<String> lines) {
  final result = <String>[];
  var index = 0;
  while (index < lines.length) {
    final String line = lines[index];
    if (fenceMarker.hasMatch(line)) {
      final int close = _fenceEnd(lines, index);
      result.addAll(lines.sublist(index, close + 1));
      index = close + 1;
      continue;
    }
    final RegExpMatch? admonition = _admonition.firstMatch(line);
    final RegExpMatch? tab = _tab.firstMatch(line);
    if (admonition == null && tab == null) {
      result.add(line);
      index += 1;
      continue;
    }
    final String indent = (admonition ?? tab)!.group(1)!;
    final int end = _bodyEnd(lines, index, indent.length + 4);
    final List<String> body = convertContainers([
      for (final bodyLine in lines.sublist(index + 1, end))
        if (bodyLine.trim().isEmpty)
          ''
        else
          bodyLine.substring(indent.length + 4),
    ]).skipWhile((bodyLine) => bodyLine.isEmpty).toList();
    if (admonition != null) {
      result.addAll(_blockquote(admonition, body, indent));
    } else {
      result
        ..add('$indent**${tab!.group(2)}**')
        ..addAll(_indented(['', ...body], indent));
    }
    if (end < lines.length && lines[end].trim().isNotEmpty) {
      result.add('');
    }
    index = end;
  }
  return result;
}

/// The index of the line that closes the fence opened at [open], or the last
/// line when it never closes.
int _fenceEnd(List<String> lines, int open) {
  final int width = fenceMarker.firstMatch(lines[open])!.group(1)!.length;
  for (var index = open + 1; index < lines.length; index += 1) {
    final RegExpMatch? match = fenceMarker.firstMatch(lines[index]);
    if (match != null &&
        match.group(1)!.length >= width &&
        match.group(2)!.trim().isEmpty) {
      return index;
    }
  }
  return lines.length - 1;
}

/// The exclusive end of the body of the container opened at [open]: every
/// following line indented by at least [width], with the blank lines between.
///
/// Trailing blank lines stay outside, so the block ends on its last content.
int _bodyEnd(List<String> lines, int open, int width) {
  var end = open + 1;
  for (var index = open + 1; index < lines.length; index += 1) {
    final String line = lines[index];
    if (line.trim().isEmpty) {
      continue;
    }
    if (RegExp(r'^ *').firstMatch(line)!.group(0)!.length < width) {
      break;
    }
    end = index + 1;
  }
  return end;
}

/// [body] quoted under the label of [opener], all behind [indent].
List<String> _blockquote(RegExpMatch opener, List<String> body, String indent) {
  final String type = opener.group(2)!;
  final String kind = '${type[0].toUpperCase()}${type.substring(1)}';
  final String? title = opener.group(3);
  final bool untitled =
      title == null ||
      title.isEmpty ||
      title.toLowerCase() == type.toLowerCase();
  final String label = untitled ? kind : '$kind: $title';
  return _indented([
    '> **$label**',
    if (body.isNotEmpty) '>',
    for (final line in body) line.isEmpty ? '>' : '> $line',
  ], indent);
}

/// [lines] behind [indent], blank lines left blank.
List<String> _indented(List<String> lines, String indent) => [
  for (final line in lines)
    if (line.isEmpty) line else '$indent$line',
];

/// Where a docs page's links can land, and how the bundle spells them.
///
/// Every page of the site sits at a path under `docs/`. A link is one of:
///
/// - to another published page: kept relative, because the bundle mirrors the
///   tree, so the same path resolves there;
/// - to a file that is not in the bundle (a repository file, a docs asset):
///   the GitHub URL of that file at the release tag;
/// - to the published site: the relative path of the page it names, when the
///   bundle has that page;
/// - to `github.com/.../(tree|blob)/main/...`: the same URL at the release
///   tag, since `main` moves and the bundle is pinned to a version.
final class DocsLinkRewriter {
  /// Rewrites links of pages in [pages] (paths relative to `docs/`).
  ///
  /// [repoUrl] and [siteUrl] come from `mkdocs.yml`, [version] is the Beak
  /// release the bundle documents, and [isRepoDirectory] says whether a
  /// repository path is a directory, which GitHub addresses as `tree`.
  DocsLinkRewriter({
    required this.pages,
    required this.repoUrl,
    required this.siteUrl,
    required this.version,
    required this.isRepoDirectory,
  });

  /// The published pages, as paths relative to `docs/`.
  final Set<String> pages;

  /// The repository URL without a trailing slash.
  final String repoUrl;

  /// The published site's URL with a trailing slash.
  final String siteUrl;

  /// The Beak version the bundle documents.
  final String version;

  /// Whether the repo-relative path is a directory.
  final bool Function(String repoPath) isRepoDirectory;

  static final RegExp _inlineLink = RegExp(
    r'(\]\()(\s*)(<?)([^()\s<>]+)(>?)((?:\s+"[^"]*")?\s*\))',
  );

  static final RegExp _definition = RegExp(
    r'^(\s{0,3}\[(?!\^)[^\]]+\]:\s+<?)([^\s>]+)(.*)$',
  );

  static final RegExp _scheme = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:');

  /// [line], a line of prose from the page at [pagePath], with its links
  /// rewritten for a page that will sit in [outputDirectory].
  ///
  /// Throws a [FormatException] for a link to a page the bundle does not
  /// have, or one that climbs out of the repository.
  String rewrite(
    String line, {
    required String pagePath,
    required String outputDirectory,
  }) {
    String target(String written) => _target(
      written,
      pageDirectory: directoryOf(pagePath),
      outputDirectory: outputDirectory,
    );
    final RegExpMatch? definition = _definition.firstMatch(line);
    if (definition != null) {
      return '${definition.group(1)}${_pin(target(definition.group(2)!))}'
          '${definition.group(3)}';
    }
    return mapOutsideCode(
      line,
      (text) => _pin(
        text.replaceAllMapped(
          _inlineLink,
          (match) =>
              '${match[1]}${match[2]}${match[3]}${target(match[4]!)}'
              '${match[5]}${match[6]}',
        ),
      ),
    );
  }

  /// [text] with `main` in repository URLs replaced by the release tag.
  String _pin(String text) => text.replaceAllMapped(
    RegExp('${RegExp.escape(repoUrl)}/(tree|blob)/main(?![\\w.-])'),
    (match) => '$repoUrl/${match[1]}/v$version',
  );

  String _target(
    String written, {
    required String pageDirectory,
    required String outputDirectory,
  }) {
    if (written.startsWith('#')) {
      return written;
    }
    if (_scheme.hasMatch(written)) {
      return written.startsWith(siteUrl)
          ? _sitePage(written.substring(siteUrl.length), outputDirectory) ??
                written
          : written;
    }
    final int hash = written.indexOf('#');
    final String anchor = hash == -1 ? '' : written.substring(hash);
    final String path = hash == -1 ? written : written.substring(0, hash);
    if (path.isEmpty) {
      return written;
    }
    final segments = <String>[
      'docs',
      if (!path.startsWith('/') && pageDirectory.isNotEmpty)
        ...pageDirectory.split('/'),
    ];
    for (final segment in path.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment != '..') {
        segments.add(segment);
      } else if (segments.isEmpty) {
        throw FormatException('the link "$written" climbs out of the repo');
      } else {
        segments.removeLast();
      }
    }
    final bool directory = path.endsWith('/');
    if (segments.isEmpty || segments.first != 'docs') {
      return _github(segments.join('/'), anchor, directory: directory);
    }
    final String docPath = segments.skip(1).join('/');
    if (docPath.endsWith('.md')) {
      if (!pages.contains(docPath)) {
        throw FormatException(
          'the link "$written" points at "$docPath", which is not a '
          'published page',
        );
      }
      return '${relativeDocPath(outputDirectory, docPath)}$anchor';
    }
    if (directory && pages.contains('$docPath/index.md')) {
      return '${relativeDocPath(outputDirectory, '$docPath/index.md')}$anchor';
    }
    return _github(
      'docs/$docPath'.replaceAll(RegExp(r'/$'), ''),
      anchor,
      directory: directory,
    );
  }

  /// The GitHub URL of the repository file at [repoPath] on the release tag.
  String _github(String repoPath, String anchor, {required bool directory}) {
    final String kind = directory || isRepoDirectory(repoPath)
        ? 'tree'
        : 'blob';
    return '$repoUrl/$kind/v$version/$repoPath$anchor';
  }

  /// The relative link to the page the site URL tail [rest] names, or `null`
  /// when the bundle has no such page.
  String? _sitePage(String rest, String outputDirectory) {
    final int hash = rest.indexOf('#');
    final String anchor = hash == -1 ? '' : rest.substring(hash);
    final String slug = (hash == -1 ? rest : rest.substring(0, hash))
        .replaceAll(RegExp(r'/+$'), '');
    final candidates = <String>[
      if (slug.isEmpty) 'index.md' else ...['$slug.md', '$slug/index.md'],
    ];
    for (final candidate in candidates) {
      if (pages.contains(candidate)) {
        return '${relativeDocPath(outputDirectory, candidate)}$anchor';
      }
    }
    return null;
  }
}

/// The directory part of the docs-relative [path], or `''` at the top.
String directoryOf(String path) {
  final int slash = path.lastIndexOf('/');
  return slash == -1 ? '' : path.substring(0, slash);
}

/// The path from directory [fromDirectory] to the file [toPath], both
/// relative to `docs/`.
String relativeDocPath(String fromDirectory, String toPath) {
  final List<String> from = fromDirectory.isEmpty
      ? const []
      : fromDirectory.split('/');
  final List<String> to = toPath.split('/');
  var shared = 0;
  while (shared < from.length &&
      shared < to.length - 1 &&
      from[shared] == to[shared]) {
    shared += 1;
  }
  return [
    for (var up = shared; up < from.length; up += 1) '..',
    ...to.skip(shared),
  ].join('/');
}
