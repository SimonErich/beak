/// Input metadata for column-level code generation.
library;

/// Whether a column should be exposed as a string-typed
/// field, comparable field, or plain field by the generator.
enum FieldKind {
  /// `StringField` with text operators.
  string,

  /// `ComparableField<T>` with comparison operators.
  comparable,

  /// `Field<T>` with equality only.
  plain,
}

/// A single column on a generator-visible model.
final class ColumnDescriptor {
  /// Creates a [ColumnDescriptor].
  const ColumnDescriptor({
    required this.dartName,
    required this.dbName,
    required this.dartType,
    this.isPrimaryKey = false,
    this.isNullable = false,
    this.fieldKind = FieldKind.plain,
  });

  /// Dart-side identifier (camelCase).
  final String dartName;

  /// Database-side identifier (snake_case).
  final String dbName;

  /// Dart static type for this column.
  final String dartType;

  /// Whether the column is the table primary key.
  final bool isPrimaryKey;

  /// Whether the column is nullable in Dart.
  final bool isNullable;

  /// Field flavour to generate for this column.
  final FieldKind fieldKind;

  /// Dart type with `?` suffix for nullable columns.
  String get nullableDartType => isNullable ? '$dartType?' : dartType;
}
