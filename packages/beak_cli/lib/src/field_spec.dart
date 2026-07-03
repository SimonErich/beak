/// The column kinds `--fields` specs can declare.
enum BeakFieldKind {
  /// Single-line string.
  string,

  /// Multiline text.
  text,

  /// Integer.
  integer,

  /// Fractional number.
  decimal,

  /// Boolean flag.
  boolean,

  /// Date and time.
  dateTime;

  /// Parses the spec token for this kind (`int` and `datetime` aliases
  /// included), or `null` for an unknown token.
  static BeakFieldKind? parse(String token) => switch (token) {
    'string' => string,
    'text' => text,
    'int' || 'integer' => integer,
    'decimal' || 'double' => decimal,
    'bool' || 'boolean' => boolean,
    'datetime' || 'date' => dateTime,
    _ => null,
  };
}

/// One typed field of a scaffolded resource, parsed from a
/// `name:kind` token.
final class BeakFieldSpec {
  /// Creates a field named [name] of [kind].
  const BeakFieldSpec({required this.name, required this.kind});

  /// Parses a single `name:kind` token.
  ///
  /// Throws a [FormatException] naming the offending token on malformed
  /// input.
  factory BeakFieldSpec.parse(String token) {
    final List<String> parts = token.split(':');
    if (parts.length != 2 || parts.first.isEmpty) {
      throw FormatException(
        'Field "$token" must look like name:kind (e.g. title:string).',
      );
    }
    final BeakFieldKind? kind = BeakFieldKind.parse(parts[1]);
    if (kind == null) {
      throw FormatException(
        'Unknown field kind "${parts[1]}" in "$token" — use one of: '
        'string, text, int, decimal, bool, datetime.',
      );
    }
    final String name = parts.first;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw FormatException('Field name "$name" must be lower_snake_case.');
    }
    return BeakFieldSpec(name: name, kind: kind);
  }

  /// Parses a comma-separated `--fields` value.
  static List<BeakFieldSpec> parseList(String spec) => [
    for (final token in spec.split(','))
      if (token.trim().isNotEmpty) BeakFieldSpec.parse(token.trim()),
  ];

  /// Snake-case column name.
  final String name;

  /// The typed column kind.
  final BeakFieldKind kind;

  /// The field name in lowerCamelCase (for Dart identifiers).
  String get camelName {
    final List<String> parts = name.split('_');
    return [
      parts.first,
      for (final part in parts.skip(1))
        if (part.isNotEmpty) '${part[0].toUpperCase()}${part.substring(1)}',
    ].join();
  }
}

/// Converts a `UpperCamelCase` resource name to `lower_snake_case`.
String snakeCaseOf(String resourceName) => resourceName
    .replaceAllMapped(
      RegExp('(?<=[a-z0-9])[A-Z]'),
      (match) => '_${match.group(0)}',
    )
    .toLowerCase();

/// The plural table name of a resource (naive `s`/`es` pluralization —
/// rename in the generated files when irregular).
String tableNameOf(String resourceName) {
  final String snake = snakeCaseOf(resourceName);
  if (snake.endsWith('s') || snake.endsWith('x') || snake.endsWith('ch')) {
    return '${snake}es';
  }
  if (snake.endsWith('y')) {
    return '${snake.substring(0, snake.length - 1)}ies';
  }
  return '${snake}s';
}
