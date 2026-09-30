/// A minimal Dart tokenizer for the repository tools.
///
/// It exists so a tool can read code without being fooled by prose: comments
/// vanish and every string or number becomes the placeholder `0`, which leaves
/// identifiers and punctuation. That is enough to find declarations
/// (`dart_declarations.dart`) and class headers (`check_hook_widgets.dart`)
/// without a dependency on the analyzer.
library;

/// Splits [source] into identifiers and punctuation.
///
/// Comments vanish, and every string or number becomes the placeholder `0`, so
/// nothing they hold can be mistaken for a declaration.
List<String> dartTokens(String source) {
  final tokens = <String>[];
  var index = 0;
  while (index < source.length) {
    final String char = source[index];
    if (char.trim().isEmpty) {
      index += 1;
    } else if (source.startsWith('//', index)) {
      final int newline = source.indexOf('\n', index);
      index = newline == -1 ? source.length : newline;
    } else if (source.startsWith('/*', index)) {
      index = _commentEnd(source, index);
    } else if (_isQuote(char) ||
        (char == 'r' &&
            index + 1 < source.length &&
            _isQuote(source[index + 1]))) {
      final bool raw = char == 'r';
      index = _stringEnd(source, raw ? index + 1 : index, raw: raw);
      tokens.add('0');
    } else if (isIdentifierStart(char)) {
      final int start = index;
      while (index < source.length && _isIdentifierPart(source[index])) {
        index += 1;
      }
      tokens.add(source.substring(start, index));
    } else if (_isDigit(char)) {
      while (index < source.length &&
          (_isIdentifierPart(source[index]) || source[index] == '.') &&
          !source.startsWith('..', index)) {
        index += 1;
      }
      tokens.add('0');
    } else {
      final String pair = source.substring(
        index,
        index + 2 > source.length ? source.length : index + 2,
      );
      if (const {'=>', '==', '!=', '<=', '>='}.contains(pair)) {
        tokens.add(pair);
        index += 2;
      } else {
        tokens.add(char);
        index += 1;
      }
    }
  }
  return tokens;
}

bool _isQuote(String char) => char == "'" || char == '"';

bool _isDigit(String char) =>
    char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

/// Whether [char] can start a Dart identifier.
bool isIdentifierStart(String char) =>
    char == '_' || char == r'$' || (char.toLowerCase() != char.toUpperCase());

bool _isIdentifierPart(String char) =>
    isIdentifierStart(char) || _isDigit(char);

/// The index just past the block comment that opens at [from], nested ones
/// included.
int _commentEnd(String source, int from) {
  var depth = 0;
  var index = from;
  while (index < source.length) {
    if (source.startsWith('/*', index)) {
      depth += 1;
      index += 2;
    } else if (source.startsWith('*/', index)) {
      depth -= 1;
      index += 2;
      if (depth == 0) {
        return index;
      }
    } else {
      index += 1;
    }
  }
  return source.length;
}

/// The index just past the string literal whose opening quote is at [from].
///
/// Handles triple quotes, escapes and `${...}` interpolation, whose code may
/// hold strings of its own. An unterminated string ends at the end of the
/// source.
int _stringEnd(String source, int from, {required bool raw}) {
  final String quote = source[from];
  final bool triple = source.startsWith(quote * 3, from);
  final String closer = triple ? quote * 3 : quote;
  var index = from + closer.length;
  while (index < source.length) {
    if (!raw && source[index] == r'\') {
      index += 2;
    } else if (!raw && source.startsWith(r'${', index)) {
      index = _interpolationEnd(source, index + 2);
    } else if (source.startsWith(closer, index)) {
      return index + closer.length;
    } else if (!triple && source[index] == '\n') {
      return index;
    } else {
      index += 1;
    }
  }
  return source.length;
}

/// The index just past the `}` closing an interpolation whose code starts at
/// [from].
int _interpolationEnd(String source, int from) {
  var depth = 1;
  var index = from;
  while (index < source.length) {
    final String char = source[index];
    if (_isQuote(char)) {
      index = _stringEnd(source, index, raw: false);
      continue;
    }
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return index + 1;
      }
    }
    index += 1;
  }
  return source.length;
}
