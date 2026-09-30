import 'inflection.dart';
import 'schema/beak_reserved_names.dart';

/// The field names `make:resource` cannot take: the key, the two stamps its
/// `timestamps: true` adds, and the name the typed record view reserves.
const Set<String> _addedByBeak = {
  'id',
  'created_at',
  'updated_at',
  ...BeakReservedNames.recordView,
};

/// The column kinds a `--fields` token can declare.
///
/// Each kind maps to a Dart type, a worm blueprint column, and a Beak
/// column in the generated code (for example [string] becomes a Dart
/// `String`, a `table.string(...)` migration column, and a
/// `BeakStringColumn`). Tokens are matched by [parse], which also accepts a
/// few aliases (`int`, `datetime`, `date`, `float`).
enum BeakFieldKind {
  /// Single-line string.
  string,

  /// Multiline text.
  text,

  /// Integer.
  integer,

  /// Exact decimal number, a `BeakDecimal` stored as integer units.
  decimal,

  /// Floating-point number, a `double`.
  floating,

  /// Boolean flag.
  boolean,

  /// Date and time.
  dateTime;

  /// Returns the kind named by [token], or `null` if it is unrecognized.
  ///
  /// Accepts the canonical name of each kind plus common aliases: `int`
  /// for [integer], `double` and `float` for [floating], `boolean` for
  /// [boolean], and `datetime`/`date` for [dateTime]. Callers that want a hard failure
  /// instead of `null` should go through [BeakFieldSpec.parse].
  ///
  /// ```dart
  /// BeakFieldKind.parse('int'); // BeakFieldKind.integer
  /// BeakFieldKind.parse('blob'); // null
  /// ```
  // --8<-- [start:fieldKindParse]
  static BeakFieldKind? parse(String token) => switch (token) {
    'string' => string,
    'text' => text,
    'int' || 'integer' => integer,
    'decimal' => decimal,
    'double' || 'float' => floating,
    'bool' || 'boolean' => boolean,
    'datetime' || 'date' => dateTime,
    _ => null,
  };
  // --8<-- [end:fieldKindParse]
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
  const BeakFieldSpec({
    required this.name,
    required this.kind,
    this.isRequired = false,
  });

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
    // A trailing `!` means required, mirroring Dart's own nullability: a
    // non-nullable field is required, and that one rule drives the form
    // validator, the API's validation and the column's NOT NULL.
    final bool isRequired = token.endsWith('!');
    final List<String> parts =
        (isRequired ? token.substring(0, token.length - 1) : token).split(':');
    if (parts.length != 2 || parts.first.isEmpty) {
      throw FormatException(
        'Field "$token" must look like name:kind (e.g. title:string).',
      );
    }
    final BeakFieldKind? kind = BeakFieldKind.parse(parts[1]);
    if (kind == null) {
      throw FormatException(
        'Unknown field kind "${parts[1]}" in "$token"; use one of: '
        'string, text, int, decimal, double, bool, datetime.',
      );
    }
    final String name = parts.first;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw FormatException('Field name "$name" must be lower_snake_case.');
    }
    if (BeakReservedNames.dartKeywords.contains(name)) {
      throw FormatException(
        'Field name "$name" is a Dart keyword, so `late final String? $name;` '
        'is not Dart. Pick another name.',
      );
    }
    if (_addedByBeak.contains(name)) {
      throw FormatException(
        'Field name "$name" is one Beak adds itself (the key, the '
        'timestamps) or reserves for the typed record view, so declaring it '
        'would declare it twice. Pick another name.',
      );
    }
    return BeakFieldSpec(name: name, kind: kind, isRequired: isRequired);
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

  /// Whether the field is non-nullable, and so required.
  ///
  /// Written as a trailing `!` — `name:string!` — mirroring Dart, where the
  /// same mark is what makes a field required everywhere else.
  final bool isRequired;

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
/// Pluralization follows [pluralOf]: the regular English rules plus a short
/// table of irregular words, so `Person` becomes `people` and `Day` becomes
/// `days`. Anything it gets wrong is named with `@Resource(table:)`.
///
/// ```dart
/// tableNameOf('Product'); // 'products'
/// tableNameOf('Category'); // 'categories'
/// tableNameOf('Box'); // 'boxes'
/// tableNameOf('Person'); // 'people'
/// ```
String tableNameOf(String resourceName) => pluralOf(snakeCaseOf(resourceName));
