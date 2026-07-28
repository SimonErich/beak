import 'package:meta/meta.dart';

import '../common/beak_color.dart';
import '../common/beak_exception.dart';
import '../context/beak_context.dart';
import '../context/beak_render_intent.dart';
import '../query/beak_record.dart';
import '../query/beak_value.dart';
import '../rules/beak_rule.dart';
import '../storage/file_rules/beak_dimensions.dart';
import '../storage/file_rules/beak_file_type.dart';
import '../storage/transforms/beak_image_transform.dart';
import 'beak_json.dart';
import 'beak_render_config.dart';

part 'beak_bool_column.dart';
part 'beak_color_column.dart';
part 'beak_custom_column.dart';
part 'beak_date_time_column.dart';
part 'beak_decimal_column.dart';
part 'beak_enum_column.dart';
part 'beak_file_column.dart';
part 'beak_image_column.dart';
part 'beak_int_column.dart';
part 'beak_json_column.dart';
part 'beak_rich_text_column.dart';
part 'beak_string_column.dart';
part 'beak_text_column.dart';

/// The heart of Beak: a typed, `const`, define-once column.
///
/// A column is declared once (as a `static const` on a user's columns class)
/// and drives every surface: table cell, form input, detail entry, and
/// filter control. The hierarchy is sealed so consumers — the frontend
/// renderer, the backend mapper — switch exhaustively and are forced to
/// handle new column types at compile time.
///
/// Never construct [BeakColumn] directly; pick the leaf that matches the
/// field's type ([BeakStringColumn], [BeakDecimalColumn], [BeakEnumColumn],
/// …). Group a resource's columns as `static const` fields so each is a
/// single, reusable, type-safe reference — users never write a string field
/// name:
///
/// ```dart
/// abstract final class ProductColumns {
///   static const name = BeakStringColumn(
///     key: 'name',
///     label: 'Name',
///     searchable: true,
///     sortable: true,
///     rules: [BeakRequired(), BeakMaxLength(255)],
///   );
///   static const price = BeakDecimalColumn(
///     key: 'price',
///     label: 'Price',
///     prefix: '€',
///     filterable: true,
///     rules: [BeakRequired(), BeakMin(0)],
///   );
///
///   static const List<BeakColumn> values = [name, price];
/// }
/// ```
@immutable
sealed class BeakColumn {
  /// Creates a column stored under [key] and labelled [label].
  const BeakColumn({
    required this.key,
    required this.label,
    this.visibleOn = const {
      BeakContext.table,
      BeakContext.form,
      BeakContext.detail,
    },
    this.sortable = false,
    this.searchable = false,
    this.filterable = false,
    this.indexed = false,
    this.unique = false,
    this.rules = const [],
  });

  /// Storage/DB column name (snake_case). Beak wires it internally; users
  /// reference the column constant itself, never this string.
  final String key;

  /// Human-readable label shown in tables, forms, and detail views.
  final String label;

  /// The surfaces this column appears on. Defaults to table, form, and
  /// detail (but not filter); narrow it to hide a field from a surface — e.g.
  /// `{BeakContext.detail}` for a read-only primary key.
  final Set<BeakContext> visibleOn;

  /// Whether table views may sort by this column.
  final bool sortable;

  /// Whether search includes this column.
  final bool searchable;

  /// Whether table views may filter by this column.
  final bool filterable;

  /// Whether the database should index this column.
  ///
  /// A migration derived from the model creates the index, so declaring it
  /// here is the whole of it. Beak indexes every belongs-to foreign key
  /// without being asked — those are joined on every list page — so this is
  /// for the columns a project sorts or filters by often.
  final bool indexed;

  /// Whether the database should enforce that this column's values are
  /// distinct.
  ///
  /// A unique index, so it also serves as one: there is no reason to declare
  /// both. Validation still happens at the API boundary; this is the
  /// guarantee underneath it.
  final bool unique;

  /// Declarative validation rules enforced on input, in order.
  final List<BeakRule> rules;

  /// The per-context render configuration of this column.
  BeakRenderConfig get renderConfig;

  /// Returns the rendering hint this column resolves to in [context] (the
  /// frontend maps each [BeakRenderIntent] to an obers_ui widget). A
  /// convenience shortcut for `renderConfig.intentFor(context)`.
  BeakRenderIntent intentFor(BeakContext context) =>
      renderConfig.intentFor(context);

  /// The Dart type this column's values take (for typed form/data access).
  Type get valueType;
}

/// A [BeakColumn] whose values are statically known to be [V].
///
/// This is what makes a column a *typed* reference rather than a labelled
/// string: given a column constant, Beak can hand back a real `String`,
/// `int`, `DateTime` or enum value instead of an `Object?` the caller has to
/// pattern-match. Every column leaf mixes it in, so
/// `ProductColumns.price.readFrom(record)` is a `double?` at compile time.
///
/// ```dart
/// final double price = ProductColumns.price.require(record);
/// final String? note = ProductColumns.note.readFrom(record);
/// ```
///
/// Implementations tolerate the wire shapes a data source may legitimately
/// produce — Postgres, for instance, returns numerics and timestamps as
/// strings over the wire — and return `null` for anything they cannot read,
/// so a malformed value never becomes a wrong value.
/// Declared without an `on BeakColumn` clause on purpose. A mixin *on* a
/// sealed type becomes an inhabitable subtype of it, which knocks out
/// exhaustiveness for every `switch` over [BeakColumn] in the codebase.
/// Requiring [key] as an interface member instead keeps the sealed hierarchy
/// exactly 13 leaves wide, and every leaf still satisfies it.
mixin BeakTypedColumn<V extends Object> {
  /// Storage/DB column name — supplied by [BeakColumn].
  String get key;

  /// The Dart type this column's values take (for typed form/data access).
  Type get valueType => V;

  /// Reads [value] as [V], or `null` when it cannot be represented as one.
  ///
  /// The single place a column decides how a stored value maps onto its Dart
  /// type. [readFrom] is the usual entry point; call this directly only when
  /// you already hold a [BeakValue].
  V? readValue(BeakValue? value);

  /// This column's value in [record], or `null` when the record does not
  /// carry a readable one.
  V? readFrom(BeakRecord record) => readValue(record[key]);

  /// This column's value in [record].
  ///
  /// Throws a [BeakRecordShapeException] naming the column when the record
  /// carries no readable value — use it for columns declaring
  /// [BeakRequired], and [readFrom] everywhere else.
  V require(BeakRecord record) =>
      readFrom(record) ??
      (throw BeakRecordShapeException(columnKey: key, expectedType: V));
}

/// Reads [value] as text, accepting any scalar a source may store.
String? _readText(BeakValue? value) => value?.raw?.toString();

/// Reads [value] as an integer, accepting wire strings and wider numerics.
int? _readInt(BeakValue? value) => switch (value?.raw) {
  final int raw => raw,
  final num raw => raw.toInt(),
  final String raw => int.tryParse(raw),
  _ => null,
};

/// Reads [value] as a double, accepting wire strings and integers.
double? _readDouble(BeakValue? value) => switch (value?.raw) {
  final num raw => raw.toDouble(),
  final String raw => double.tryParse(raw),
  _ => null,
};

/// Reads [value] as a boolean, accepting the canonical wire strings and the
/// 0/1 integers SQLite stores booleans as.
bool? _readBool(BeakValue? value) => switch (value?.raw) {
  final bool raw => raw,
  'true' || 1 => true,
  'false' || 0 => false,
  _ => null,
};

/// Reads [value] as an instant, accepting ISO-8601 wire strings.
DateTime? _readDateTime(BeakValue? value) => switch (value?.raw) {
  final DateTime raw => raw,
  final String raw => DateTime.tryParse(raw),
  _ => null,
};

/// Shared shape of the upload-backed columns ([BeakImageColumn],
/// [BeakFileColumn]): where uploads land and which size/type rules gate
/// them — consumers of upload rules match this one type instead of the
/// two leaves.
// --8<-- [start:BeakUploadColumn]
sealed class BeakUploadColumn extends BeakColumn {
  /// Creates an upload-backed column storing files under [storagePath].
  const BeakUploadColumn({
    required super.key,
    required super.label,
    required this.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
    this.maxSizeInBytes,
    this.allowedTypes = const [],
  });

  /// Storage subfolder uploads of this column land in.
  final String storagePath;

  /// Highest accepted upload size in bytes, if bounded.
  final int? maxSizeInBytes;

  /// Accepted upload types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;
}

// --8<-- [end:BeakUploadColumn]
