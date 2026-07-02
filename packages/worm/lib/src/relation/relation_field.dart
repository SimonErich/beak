/// Typed reference to a relation declared on a model.
library;

import '../model/model.dart';

/// Compile-time reference to a relation by name.
///
/// Generated companion classes emit `RelationField` constants
/// — for example `User$.posts` and `User$.profile` — so callers
/// can refer to a relation without using its raw string name.
/// The instance carries no load logic; it points at the runtime
/// relation accessor through [name].
///
/// Type parameters are the **parent** and the **related** model
/// classes (not the accessor cardinality — that's encoded by
/// the relation definition site). [foreignKey] is the column on
/// the related table that points back at the parent, and
/// [localKey] is the parent column it references (`id` by
/// default).
///
/// ```dart
/// // Generated for `User` from `@HasMany(Post)`:
/// static const posts = RelationField<User, Post>(
///   'posts',
///   foreignKey: 'user_id',
/// );
/// ```
final class RelationField<Parent extends Model, Related extends Model> {
  /// Creates a [RelationField] referencing [name].
  const RelationField(
    this.name, {
    required this.foreignKey,
    this.localKey = 'id',
  });

  /// Stable name of the relation on the parent model.
  ///
  /// Matches the camelCase identifier on the model class. The
  /// eager loader and `Model.relations` map both key on this
  /// value.
  final String name;

  /// Column on the related table that carries the parent's
  /// primary key.
  final String foreignKey;

  /// Column on the parent table that [foreignKey] points at.
  /// Defaults to `'id'`.
  final String localKey;

  /// Build a nested [RelationPath] rooted at this field, descending
  /// through [children] in declaration order.
  ///
  /// ```dart
  /// query.withRelation(User$.posts.include([Post$.comments]));
  /// ```
  RelationPath include(List<RelationField<Model, Model>> children) {
    final names = <String>[name, for (final child in children) child.name];
    return RelationPath(names.join('.'));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationField<Parent, Related> &&
          name == other.name &&
          foreignKey == other.foreignKey &&
          localKey == other.localKey;

  @override
  int get hashCode => Object.hash(Parent, Related, name, foreignKey, localKey);

  @override
  String toString() =>
      'RelationField<$Parent, $Related>($name, '
      'foreignKey=$foreignKey, localKey=$localKey)';
}

/// Dot-joined nested relation path, produced by
/// [RelationField.include].
///
/// The runtime collapses the chain back to a single dot-notation
/// string consumed by `EagerLoader`, e.g. `'posts.comments'`.
final class RelationPath {
  /// Creates a [RelationPath].
  const RelationPath(this.path);

  /// Dot-separated relation path
  /// (e.g. `'posts'` or `'posts.comments'`).
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RelationPath && path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'RelationPath($path)';
}

/// Spec-vocabulary alias for [RelationPath].
///
/// `RelationField.include(...)` is documented as returning a
/// "relation load spec"; this typedef makes that reading literal in
/// callers without forcing a second class hierarchy.
typedef RelationLoadSpec = RelationPath;
