/// Input metadata for relation-level code generation.
library;

/// The cardinality of a relation declared on a model.
///
/// Recorded for documentation and to drive any cardinality-
/// sensitive code generation downstream — the emitted
/// `RelationField<Parent, Related>` constant itself is the same
/// shape regardless of cardinality.
enum RelationDescriptorKind {
  /// Single related model (`HasOne`, `BelongsTo`, `MorphOne`,
  /// `MorphTo`, `HasOneThrough`).
  one,

  /// Many related models (`HasMany`, `BelongsToMany`,
  /// `MorphMany`, `MorphToMany`, `HasManyThrough`).
  many,
}

/// Describes a generator-visible relation on a model.
///
/// The companion generator emits one
/// `RelationField<Parent, Related>` constant per descriptor
/// under [dartName], wired with [foreignKey] and [localKey] so
/// factories can resolve the linking columns without a runtime
/// lookup.
final class RelationDescriptor {
  /// Creates a [RelationDescriptor].
  const RelationDescriptor({
    required this.dartName,
    required this.relatedClassName,
    required this.kind,
    required this.foreignKey,
    this.localKey = 'id',
  });

  /// CamelCase identifier on the parent model. Used both as the
  /// constant name on the companion (`User$.posts`) and as the
  /// relation name passed through the runtime.
  final String dartName;

  /// PascalCase Dart class name of the related model. Emitted
  /// as the `Related` type argument of the
  /// `RelationField<Parent, Related>` constant.
  final String relatedClassName;

  /// Cardinality of the relation.
  final RelationDescriptorKind kind;

  /// Column on the related table carrying the parent's primary
  /// key (e.g. `user_id` for `User.posts`).
  final String foreignKey;

  /// Column on the parent table that [foreignKey] points at.
  /// Defaults to `'id'`.
  final String localKey;
}
