/// A Dart single-quoted string literal for [value].
String dartString(String value) {
  final String escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// A Dart literal for a YAML scalar: a string, a number, a bool or null.
///
/// Returns `null` for anything else (a list or a map), which no generated
/// constant holds.
String? dartLiteral(Object? value) => switch (value) {
  final String text => dartString(text),
  null => 'null',
  final bool flag => '$flag',
  final num number => '$number',
  _ => null,
};

/// `product_variant` -> `productVariant`.
String camelCaseOf(String snake) {
  final parts = snake.split('_').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return snake;
  return parts.first +
      parts
          .skip(1)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join();
}

/// The first letter of [name] in lower case.
String lowerFirst(String name) =>
    name.isEmpty ? name : '${name[0].toLowerCase()}${name.substring(1)}';

/// The first letter of [name] in upper case.
String upperFirst(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

/// Splits [input] at top-level commas, leaving brackets and quotes intact.
List<String> splitTopLevel(String input) {
  final result = <String>[];
  var depth = 0;
  var start = 0;
  String? quote;
  for (var index = 0; index < input.length; index++) {
    final String character = input[index];
    if (quote != null) {
      if (character == quote && input[index - 1] != r'\') quote = null;
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
    } else if ('(<['.contains(character)) {
      depth++;
    } else if (')>]'.contains(character)) {
      depth--;
    } else if (character == ',' && depth == 0) {
      result.add(input.substring(start, index).trim());
      start = index + 1;
    }
  }
  result.add(input.substring(start).trim());
  return [
    for (final part in result)
      if (part.isNotEmpty) part,
  ];
}
