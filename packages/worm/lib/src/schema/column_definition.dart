/// Column definition used by the schema builder.
library;

import 'column_type.dart';

/// A column definition produced by the schema builder.
///
/// Carries everything required to render a `CREATE TABLE`
/// column clause for SQL adapters and to describe a field for
/// the MongoDB adapter.
///
/// Modifiers (`primary`, `makeNullable`, `makeUnique`, ...)
/// mutate the receiver in place. Use Dart's cascade operator
/// to chain them: `table.uuid('id')..primary()..makeUnique()`.
final class ColumnDefinition {
  /// Creates a [ColumnDefinition].
  ColumnDefinition({
    required this.name,
    required this.type,
    this.length,
    this.precision,
    this.scale,
    this.elementType,
    this.enumValues = const <String>[],
    this.nullable = false,
    this.isPrimaryKey = false,
    this.autoIncrement = false,
    this.unique = false,
    this.defaultValue,
    this.comment,
    this.generatedAs,
  });

  /// Column name (snake_case in the database).
  final String name;

  /// Abstract column type.
  final ColumnType type;

  /// Optional length for `string` columns.
  int? length;

  /// Optional precision for `decimal` columns.
  int? precision;

  /// Optional scale for `decimal` columns.
  int? scale;

  /// Element type when [type] is [ColumnType.array].
  ColumnType? elementType;

  /// Enum value list when [type] is [ColumnType.enumType].
  List<String> enumValues;

  /// Whether the column allows `NULL`.
  bool nullable;

  /// Whether this column is the table's primary key.
  bool isPrimaryKey;

  /// Whether the column is an auto-incrementing integer.
  bool autoIncrement;

  /// Whether this column has a unique constraint.
  bool unique;

  /// Default value expression.
  Object? defaultValue;

  /// Optional column comment.
  String? comment;

  /// Generated-column expression.
  String? generatedAs;

  /// Whether this definition modifies an existing column rather than adding
  /// one. Only meaningful inside `Schema.alter`.
  bool isChange = false;

  /// Marks this definition as a modification of an existing column.
  ///
  /// Reuses the whole column builder, so changing a type reads the same way
  /// as declaring one: `table.string('bio', length: 500)..change();`. The
  /// definition is the column's complete end state, not a delta — MySQL's
  /// `MODIFY COLUMN` cannot express a partial change.
  ///
  /// Valid only inside `Schema.alter`; `Schema.create` rejects it.
  void change() {
    isChange = true;
  }

  /// Marks this column nullable.
  void makeNullable() {
    nullable = true;
  }

  /// Marks this column as the primary key.
  void primary() {
    isPrimaryKey = true;
  }

  /// Marks this column as auto-increment.
  void autoIncrementing() {
    autoIncrement = true;
  }

  /// Adds a unique constraint to this column.
  void makeUnique() {
    unique = true;
  }

  /// Sets the default value.
  void withDefault(Object? value) {
    defaultValue = value;
  }

  /// Sets a column comment.
  void withComment(String text) {
    comment = text;
  }

  /// Marks this column as a generated column.
  void generated(String expression) {
    generatedAs = expression;
  }

  /// Serializes the column to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'type': type.name,
    if (length != null) 'length': length,
    if (precision != null) 'precision': precision,
    if (scale != null) 'scale': scale,
    if (elementType != null) 'elementType': elementType?.name,
    if (enumValues.isNotEmpty) 'enumValues': enumValues,
    'nullable': nullable,
    if (isPrimaryKey) 'isPrimaryKey': true,
    if (autoIncrement) 'autoIncrement': true,
    if (unique) 'unique': true,
    if (defaultValue != null) 'default': defaultValue,
    if (comment != null) 'comment': comment,
    if (generatedAs != null) 'generatedAs': generatedAs,
  };
}
