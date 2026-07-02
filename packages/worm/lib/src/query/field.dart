/// Type-safe field references for query building.
library;

/// A typed reference to a database column.
///
/// [T] is the Dart type of the column value.
/// Use [ComparableField] for numeric and date fields
/// and [StringField] for text fields.
///
/// ```dart
/// const isActive = Field<bool>('is_active');
/// ```
final class Field<T> {
  /// Creates a [Field] referencing [name].
  const Field(this.name, {this.tableName});

  /// The column name in the database.
  final String name;

  /// Optional table qualifier.
  final String? tableName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Field<T> && name == other.name && tableName == other.tableName;

  @override
  int get hashCode => Object.hash(name, tableName);

  @override
  String toString() => tableName != null ? '$tableName.$name' : name;
}

/// A field whose values support ordering.
///
/// Exposes comparison operators like `gt`, `gte`,
/// `lt`, `lte`, `between`, and `notBetween` via
/// `ComparableFieldOperators`.
///
/// ```dart
/// const age = ComparableField<int>('age');
/// ```
final class ComparableField<T> extends Field<T> {
  /// Creates a [ComparableField] referencing [name].
  const ComparableField(super.name, {super.tableName});
}

/// A field whose value is a [String].
///
/// Exposes string operators like `like`, `contains`,
/// `startsWith`, and `endsWith` via
/// `StringFieldOperators`.
///
/// ```dart
/// const name = StringField('name');
/// ```
final class StringField extends Field<String> {
  /// Creates a [StringField] referencing [name].
  const StringField(super.name, {super.tableName});
}
