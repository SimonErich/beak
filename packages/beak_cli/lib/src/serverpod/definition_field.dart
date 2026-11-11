/// The relationship annotation on a definition field.
enum DefinitionRelationKind {
  /// `@BelongsTo`.
  belongsTo,

  /// `@HasOne`.
  hasOne,

  /// `@HasMany`.
  hasMany,
}

/// A relationship a definition field declares.
final class DefinitionRelation {
  /// Creates a relationship.
  const DefinitionRelation({
    required this.kind,
    required this.target,
    this.owned = false,
    this.label,
  });

  /// The annotation that declares it.
  final DefinitionRelationKind kind;

  /// The class on the far side.
  final String target;

  /// Whether the related rows are saved with this record.
  final bool owned;

  /// The `label:` of the annotation.
  final String? label;
}

/// One field a definition class declares.
final class DefinitionField {
  /// Creates a field.
  const DefinitionField({
    required this.name,
    required this.typeName,
    required this.nullable,
    this.display = false,
    this.readOnly = false,
    this.hidden = false,
    this.hiddenDefault,
    this.columnArguments = const {},
    this.label,
    this.relation,
    this.docComment,
  });

  /// The field name, which is the Serverpod field's.
  final String name;

  /// The declared type, with type arguments (`List<ProductTag>`).
  final String typeName;

  /// Whether the type ends in `?`.
  final bool nullable;

  /// Whether the field is the `@Display()` column.
  final bool display;

  /// Whether the field is `@ReadOnly()`.
  final bool readOnly;

  /// Whether the field is `@Hidden()`.
  final bool hidden;

  /// The `@Hidden(defaultValue:)` literal, or `null` for none.
  final Object? hiddenDefault;

  /// The `@Column(...)` arguments as source, except `label`.
  final Map<String, String> columnArguments;

  /// The `@Column(label:)` text.
  final String? label;

  /// The relationship the field declares, or `null` for a column.
  final DefinitionRelation? relation;

  /// The field's doc comment, without the `///` markers.
  final String? docComment;
}
