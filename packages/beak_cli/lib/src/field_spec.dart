/// The column kinds a `--fields` token can declare.
///
/// Each kind maps to a Dart type, a worm blueprint column, and a Beak
/// column in the generated code (for example [string] becomes a Dart
/// `String`, a `table.string(...)` migration column, and a
/// `BeakStringColumn`). Tokens are matched by [parse], which also accepts a
/// few aliases (`int`, `datetime`, `date`, `double`).
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

  /// Returns the kind named by [token], or `null` if it is unrecognized.
  ///
  /// Accepts the canonical name of each kind plus common aliases: `int`
  /// for [integer], `double` for [decimal], `boolean` for [boolean], and
  /// `datetime`/`date` for [dateTime]. Callers that want a hard failure
  /// instead of `null` should go through [BeakFieldSpec.parse].
  ///
  /// ```dart
  /// BeakFieldKind.parse('int'); // BeakFieldKind.integer
  /// BeakFieldKind.parse('blob'); // null
  /// ```
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

/// One typed field of a scaffolded resource, parsed from a `name:kind`
/// token such as `price:decimal`.
///
/// A field carries its snake-case column [name] and its [kind]; the
/// generators read both to emit the Dart getter, migration column, and
/// Beak column for it. The camel-case Dart identifier is derived on demand
/// via [camelName].
///
/// ```dart
/// final specs = BeakFieldSpec.parseList(
///   'name:string,price:decimal,released_at:datetime',
/// );
/// specs.last.name; // 'released_at'
/// specs.last.camelName; // 'releasedAt'
/// specs.last.kind; // BeakFieldKind.dateTime
/// ```
final class BeakFieldSpec {
  /// Creates a field named [name] (lower_snake_case) of the given [kind].
  const BeakFieldSpec({required this.name, required this.kind});

  /// Parses a single `name:kind` token into a [BeakFieldSpec].
  ///
  /// The token must be exactly `name:kind` where `name` is
  /// lower_snake_case and `kind` is a token accepted by
  /// [BeakFieldKind.parse]. Throws a [FormatException] whose message names
  /// the offending token when the shape, the name casing, or the kind is
  /// invalid.
  ///
  /// ```dart
  /// BeakFieldSpec.parse('title:string'); // ok
  /// BeakFieldSpec.parse('nameonly'); // throws FormatException
  /// ```
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

  /// Parses a comma-separated `--fields` value into an ordered list.
  ///
  /// Whitespace around each token is trimmed and empty tokens are skipped,
  /// so a trailing comma or an empty [spec] yields the surviving fields (or
  /// an empty list). Each non-empty token is delegated to
  /// [BeakFieldSpec.parse], so a malformed token still throws a
  /// [FormatException].
  ///
  /// ```dart
  /// BeakFieldSpec.parseList('name:string, price:decimal');
  /// // [BeakFieldSpec(name), BeakFieldSpec(price)]
  /// ```
  static List<BeakFieldSpec> parseList(String spec) => [
    for (final token in spec.split(','))
      if (token.trim().isNotEmpty) BeakFieldSpec.parse(token.trim()),
  ];

  /// The lower_snake_case column and attribute name (e.g. `released_at`).
  final String name;

  /// The typed column kind that drives type and column generation.
  final BeakFieldKind kind;

  /// The [name] rewritten to lowerCamelCase for use as a Dart identifier.
  ///
  /// Splits on underscores and upper-cases each subsequent segment, so
  /// `released_at` becomes `releasedAt`.
  String get camelName {
    final List<String> parts = name.split('_');
    return [
      parts.first,
      for (final part in parts.skip(1))
        if (part.isNotEmpty) '${part[0].toUpperCase()}${part.substring(1)}',
    ].join();
  }
}

/// Converts an `UpperCamelCase` resource name to `lower_snake_case`.
///
/// Used to derive file names and the singular table stem from a resource
/// name (for example `OrderItem` becomes `order_item`).
///
/// ```dart
/// snakeCaseOf('OrderItem'); // 'order_item'
/// ```
String snakeCaseOf(String resourceName) => resourceName
    .replaceAllMapped(
      RegExp('(?<=[a-z0-9])[A-Z]'),
      (match) => '_${match.group(0)}',
    )
    .toLowerCase();

/// Returns the plural, snake-case table name for [resourceName].
///
/// Pluralization is deliberately naive: `s`/`x`/`ch` endings take `es`, a
/// trailing `y` becomes `ies`, and everything else takes `s`. It is right
/// often enough to scaffold from; rename the generated `tableName` and
/// migration when a resource pluralizes irregularly.
///
/// ```dart
/// tableNameOf('Product'); // 'products'
/// tableNameOf('Category'); // 'categories'
/// tableNameOf('Box'); // 'boxes'
/// ```
String tableNameOf(String resourceName) => pluralOf(snakeCaseOf(resourceName));

/// `category` -> `categories`, `box` -> `boxes`, `product` -> `products`.
///
/// The one pluraliser: a table name and the migration class naming it must
/// agree, and appending a bare `s` gave `CreateCategorysTable` beside a
/// `categories` table.
///
/// ```dart
/// pluralOf('Category'); // 'Categories'
/// pluralOf('product');  // 'products'
/// ```
String pluralOf(String word) {
  if (word.endsWith('s') || word.endsWith('x') || word.endsWith('ch')) {
    return '${word}es';
  }
  if (word.endsWith('y')) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  return '${word}s';
}
