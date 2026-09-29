/// The public names a Dart source file declares.
///
/// `tool/build_agent_docs.dart` uses it to prove a corrections-table row: a
/// symbol the docs say exists must be declared somewhere, and one they say is
/// removed must not be. Counting every word of the source, as the tool first
/// did, cannot prove a removal, because a doc comment, a message string, a
/// local variable or a private helper keeps the word alive long after the API
/// is gone.
///
/// This is a scanner, not a parser. It reads declarations at library and
/// class-body level, keeps the names in their headers (types, members,
/// parameters), and skips everything that cannot be API: comments, strings,
/// function bodies, initializer expressions, private declarations and the
/// insides of private classes.
library;

import 'dart_tokens.dart';

/// The names declared in public API position in [source].
///
/// A name is a type, member or parameter that appears in a declaration header
/// and does not start with an underscore. Nothing inside a body or an
/// initializer counts, so a removed name that only survives in a comment, a
/// string or a local variable is not in the result.
Set<String> publicNamesIn(String source) {
  final List<String> tokens = dartTokens(source);
  final names = <String>{};
  _scan(tokens, 0, tokens.length, names);
  return names;
}

/// The keywords that open a type body whose members are scanned.
const Set<String> _typeKeywords = {'class', 'mixin', 'enum', 'extension'};

/// Reads the declarations in `tokens[from, to)` and adds their public names to
/// [names].
void _scan(List<String> tokens, int from, int to, Set<String> names) {
  var index = from;
  while (index < to) {
    final header = <String>[];
    var depth = 0;
    var inInitializerList = false;
    var bodyAt = -1;
    while (index < to) {
      final String token = tokens[index];
      if (token == '(' || token == '[') {
        depth += 1;
      } else if (token == ')' || token == ']') {
        depth -= 1;
      } else if (depth == 0) {
        if (token == ';') {
          index += 1;
          break;
        }
        if (token == '{') {
          bodyAt = index;
          break;
        }
        if (token == '=>' || (token == '=' && !inInitializerList)) {
          index = _statementEnd(tokens, index + 1, to);
          break;
        }
        if (token == ':') {
          inInitializerList = true;
        }
      }
      header.add(token);
      index += 1;
    }
    final List<String> declaration = _withoutAnnotations(header);
    final String? name = _declaredName(declaration);
    final bool private = name != null && name.startsWith('_');
    if (!private) {
      names.addAll(declaration.where(_isPublicIdentifier));
    }
    if (bodyAt != -1) {
      final int close = _blockEnd(tokens, bodyAt, to);
      if (!private && declaration.any(_typeKeywords.contains)) {
        _scan(tokens, bodyAt + 1, close, names);
      }
      index = close + 1;
    }
  }
}

/// The index of the `;` that ends the statement starting at [from], or [to].
///
/// Brackets nest, so a closure body or a map literal in an initializer does
/// not end it early. The index returned is past the `;`.
int _statementEnd(List<String> tokens, int from, int to) {
  var depth = 0;
  for (var index = from; index < to; index += 1) {
    final String token = tokens[index];
    if (token == '(' || token == '[' || token == '{') {
      depth += 1;
    } else if (token == ')' || token == ']' || token == '}') {
      depth -= 1;
    } else if (token == ';' && depth <= 0) {
      return index + 1;
    }
  }
  return to;
}

/// The index of the `}` matching the `{` at [open], or [to] when unbalanced.
int _blockEnd(List<String> tokens, int open, int to) {
  var depth = 0;
  for (var index = open; index < to; index += 1) {
    if (tokens[index] == '{') {
      depth += 1;
    } else if (tokens[index] == '}') {
      depth -= 1;
      if (depth == 0) {
        return index;
      }
    }
  }
  return to;
}

/// [header] without its leading `@annotation(...)` groups.
List<String> _withoutAnnotations(List<String> header) {
  var index = 0;
  while (index < header.length && header[index] == '@') {
    index += 1;
    if (index < header.length) {
      index += 1;
    }
    while (index + 1 < header.length && header[index] == '.') {
      index += 2;
    }
    if (index < header.length && header[index] == '(') {
      var depth = 0;
      do {
        if (header[index] == '(') {
          depth += 1;
        } else if (header[index] == ')') {
          depth -= 1;
        }
        index += 1;
      } while (index < header.length && depth > 0);
    }
  }
  return header.sublist(index);
}

/// The name [declaration] introduces, or `null` when it cannot tell.
///
/// The word after `class`, `mixin`, `enum` or `extension` for a type, else the
/// last identifier before the parameter list, or before the end of a field.
String? _declaredName(List<String> declaration) {
  for (var index = 0; index < declaration.length - 1; index += 1) {
    if (_typeKeywords.contains(declaration[index])) {
      var next = index + 1;
      if (declaration[index] == 'extension' && declaration[next] == 'type') {
        next += 1;
      }
      return next < declaration.length &&
              isIdentifierStart(declaration[next][0])
          ? declaration[next]
          : null;
    }
  }
  String? name;
  for (final token in declaration) {
    if (token == '(') {
      break;
    }
    if (isIdentifierStart(token[0])) {
      name = token;
    }
  }
  return name;
}

bool _isPublicIdentifier(String token) =>
    isIdentifierStart(token[0]) && !token.startsWith('_');
