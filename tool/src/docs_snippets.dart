/// The `--8<--` snippet directive the docs use to quote source.
///
/// `tool/check_docs.dart` checks that every include still resolves, and
/// `tool/build_agent_docs.dart` expands them the way `pymdownx.snippets` does
/// with `base_path: [.]` and `dedent_subsections: true`. Both read the
/// directive through this file, so they cannot disagree about what one is.
library;

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

/// A section marker as pymdownx reads one on a line of a page.
///
/// Broader than [snippetMarker], which reads the source files a page quotes:
/// pymdownx wants whitespace before the bracket, a name that starts with a
/// letter, and takes any number of dashes, so a lookalike outside that grammar
/// is left on the page. Case does not matter. Group 1 is what precedes the
/// marker, group 2 the escaping semicolons directly before it.
final RegExp pageSnippetMarker = RegExp(
  r'^(.*?)(;*)(-+8<-+[ \t]+\[[ \t]*(?:start|end)[ \t]*:[ \t]*'
  r'[a-z][-_0-9a-z]*[ \t]*\])',
  caseSensitive: false,
);

/// [line] of a page as pymdownx leaves it, or `null` when it deletes the line.
///
/// A line holding a section marker is removed before Markdown sees the page,
/// whether it sits in a fence, in inline code or in prose. One semicolon
/// directly before the marker escapes it: the line stays and the semicolon
/// goes, which is the only way to show a marker to a reader.
String? renderedPageLine(String line) {
  final RegExpMatch? marker = pageSnippetMarker.firstMatch(line);
  if (marker == null) {
    return line;
  }
  final String escape = marker.group(2)!;
  if (escape.isEmpty) {
    return null;
  }
  final String before = marker.group(1)!;
  return '$before${escape.substring(1)}'
      '${line.substring(before.length + escape.length)}';
}

/// Whether [reference] selects lines by number (`file.dart:12:20`).
///
/// pymdownx reads it, but there is no marker to watch, so a rename moves the
/// quoted lines without a build noticing, and the agent docs bundle refuses it.
bool isLineRange(String reference) =>
    reference.contains(':') && sectionOf(reference) == null;

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

/// Reads the repository file at a repo-relative path, or returns `null` when
/// it is not there.
typedef SnippetReader = String? Function(String path);

/// An include that cannot be expanded.
final class SnippetException implements Exception {
  /// Reports [message] for the include on 0-based line [line] of the input.
  const SnippetException(this.message, this.line);

  /// What is wrong with the include.
  final String message;

  /// The 0-based index, in the lines handed to [expandSnippets], of the
  /// include that failed.
  final int line;

  @override
  String toString() => 'line ${line + 1}: $message';
}

/// [lines] with every `--8<--` include line replaced by the file it names.
///
/// This is what `pymdownx.snippets` does, in the same order it does it, before
/// any other Markdown extension sees the page:
///
/// - `--8<-- "path"` becomes the whole file, and `--8<-- "path:name"` the
///   lines between its `[start:name]` and `[end:name]` markers, dedented
///   together. Marker lines never reach the page.
/// - The include's own indentation is kept on every line it produces, so an
///   include inside an admonition or a tab stays inside it.
/// - Includes inside included files expand too.
/// - A line that holds a section marker is dropped, or loses the one escaping
///   semicolon before the marker ([renderedPageLine]).
///
/// Where mkdocs would publish an empty block, this throws a
/// [SnippetException]: a missing file, a section with no start marker, one
/// that never closes, a range form (`path:1:10`, which has no marker for a
/// check to watch) or an include cycle.
List<String> expandSnippets(
  List<String> lines, {
  required SnippetReader readFile,
  Set<String> including = const {},
}) {
  final expanded = <String>[];
  for (var index = 0; index < lines.length; index += 1) {
    final String line = lines[index];
    final RegExpMatch? include = snippetInclude.firstMatch(line);
    if (include == null) {
      final String? rendered = renderedPageLine(line);
      if (rendered != null) {
        expanded.add(rendered);
      }
      continue;
    }
    final String indent = RegExp(r'^\s*').firstMatch(line)!.group(0)!;
    final List<String> body;
    try {
      body = _included(
        include.group(1)!,
        readFile: readFile,
        including: including,
      );
    } on FormatException catch (exception) {
      throw SnippetException(exception.message, index);
    }
    for (final bodyLine in body) {
      expanded.add(bodyLine.isEmpty ? bodyLine : '$indent$bodyLine');
    }
  }
  return expanded;
}

/// The lines the include of [reference] stands for, includes expanded.
///
/// Throws a [FormatException] for anything [expandSnippets] must reject.
List<String> _included(
  String reference, {
  required SnippetReader readFile,
  required Set<String> including,
}) {
  final String target = reference.split(':').first;
  final String? section = sectionOf(reference);
  if (isLineRange(reference)) {
    throw FormatException(
      'snippet "$reference" is a line range; only whole files and '
      '"file:section" includes are supported',
    );
  }
  if (including.contains(reference)) {
    throw FormatException('snippet "$reference" includes itself');
  }
  final String? contents = readFile(target);
  if (contents == null) {
    throw FormatException('snippet includes "$target", which does not exist');
  }
  final List<String> source = _linesOf(contents);
  final List<String> chosen = section == null
      ? source
      : _sectionLines(source, section: section, target: target);
  final List<String> kept = [
    for (final line in chosen)
      if (!snippetMarker.hasMatch(line)) line,
  ];
  try {
    return expandSnippets(
      section == null ? kept : dedent(kept),
      readFile: readFile,
      including: {...including, reference},
    );
  } on SnippetException catch (nested) {
    throw FormatException('in "$target", ${nested.message}');
  }
}

/// [contents] as lines, without the empty one a trailing newline leaves.
List<String> _linesOf(String contents) {
  final List<String> lines = contents.replaceAll('\r\n', '\n').split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// The lines of [source] between the markers of [section], markers included.
///
/// Markers of other sections inside it come along, and the caller drops them.
List<String> _sectionLines(
  List<String> source, {
  required String section,
  required String target,
}) {
  int? start;
  int? end;
  for (var index = 0; index < source.length; index += 1) {
    for (final marker in snippetMarker.allMatches(source[index])) {
      if (marker.group(2) != section) {
        continue;
      }
      if (marker.group(1) == 'start') {
        start ??= index;
      } else if (start != null) {
        end ??= index;
      }
    }
  }
  if (start == null) {
    throw FormatException(
      'snippet includes section "$section" of "$target", which has no '
      '"--8<-- [start:$section]" marker',
    );
  }
  if (end == null) {
    throw FormatException(
      'snippet includes section "$section" of "$target", which opens the '
      'section but never closes it with "--8<-- [end:$section]"',
    );
  }
  return source.sublist(start + 1, end);
}

/// [lines] without the leading whitespace they all share, as
/// `textwrap.dedent` does.
///
/// Blank lines take no part in the measurement and come out empty.
List<String> dedent(List<String> lines) {
  String? margin;
  for (final line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }
    final String leading = RegExp(r'^[ \t]*').firstMatch(line)!.group(0)!;
    margin = margin == null ? leading : _commonPrefix(margin, leading);
  }
  final int width = margin?.length ?? 0;
  return [
    for (final line in lines)
      if (line.trim().isEmpty) '' else line.substring(width),
  ];
}

/// The longest prefix [a] and [b] share.
String _commonPrefix(String a, String b) {
  var length = 0;
  while (length < a.length && length < b.length && a[length] == b[length]) {
    length += 1;
  }
  return a.substring(0, length);
}
