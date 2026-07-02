/// All annotation classes for worm models.
///
/// ```dart
/// import 'package:worm/annotations.dart';
/// ```
library;

import 'src/schema/column_type.dart';
import 'src/schema/on_delete.dart';
import 'src/schema/primary_key_type.dart';

export 'src/schema/on_delete.dart';

/// Maps a class to a database table.
class Table {
  /// Creates a [Table] annotation.
  const Table({this.name, this.connection = 'default'});

  /// Table name override. Defaults to the
  /// snake_case class name if omitted.
  final String? name;

  /// Named database connection to use.
  final String connection;
}

/// Configures a model field as a database column.
class Column {
  /// Creates a [Column] annotation.
  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.defaultValue,
  });

  /// Column name override.
  final String? name;

  /// Explicit column type.
  final ColumnType? type;

  /// Whether the column allows NULL values.
  final bool nullable;

  /// Default value for the column.
  final Object? defaultValue;
}

/// Marks a field as the primary key.
class PrimaryKey {
  /// Creates a [PrimaryKey] annotation.
  const PrimaryKey({this.columnName = 'id', this.type = PrimaryKeyType.uuid});

  /// Column name for the primary key.
  final String columnName;

  /// Primary key generation strategy.
  final PrimaryKeyType type;
}

/// Defines a has-one relationship.
class HasOne {
  /// Creates a [HasOne] annotation.
  const HasOne(
    this.related, {
    this.foreignKey,
    this.localKey,
    this.onDelete = OnDelete.restrict,
  });

  /// The related model type.
  final Type related;

  /// Foreign key on the related table.
  final String? foreignKey;

  /// Local key on this table.
  final String? localKey;

  /// Action taken on the dependent row when the parent is deleted.
  ///
  /// Read by the generator to emit the parent's `ormCascadeSpecs`
  /// when set to [OnDelete.ormCascade], or to emit the matching
  /// database-level foreign-key clause otherwise.
  final OnDelete onDelete;
}

/// Defines a has-many relationship.
class HasMany {
  /// Creates a [HasMany] annotation.
  const HasMany(
    this.related, {
    this.foreignKey,
    this.localKey,
    this.onDelete = OnDelete.restrict,
  });

  /// The related model type.
  final Type related;

  /// Foreign key on the related table.
  final String? foreignKey;

  /// Local key on this table.
  final String? localKey;

  /// Action taken on dependent rows when the parent is deleted.
  ///
  /// Read by the generator to emit the parent's `ormCascadeSpecs`
  /// when set to [OnDelete.ormCascade], or to emit the matching
  /// database-level foreign-key clause otherwise.
  final OnDelete onDelete;
}

/// Defines an inverse belongs-to relationship.
class BelongsTo {
  /// Creates a [BelongsTo] annotation.
  const BelongsTo(this.related, {this.foreignKey, this.ownerKey});

  /// The parent model type.
  final Type related;

  /// Foreign key on this table.
  final String? foreignKey;

  /// Owner key on the parent table.
  final String? ownerKey;
}

/// Defines a many-to-many relationship through
/// a pivot table.
class BelongsToMany {
  /// Creates a [BelongsToMany] annotation.
  const BelongsToMany(
    this.related, {
    this.pivotTable,
    this.foreignPivotKey,
    this.relatedPivotKey,
    this.onDelete = OnDelete.restrict,
  });

  /// The related model type.
  final Type related;

  /// Explicit pivot table name.
  final String? pivotTable;

  /// Foreign key column in the pivot table.
  final String? foreignPivotKey;

  /// Related key column in the pivot table.
  final String? relatedPivotKey;

  /// Action when a related record is deleted.
  final OnDelete onDelete;
}

/// Defines a has-one-through relationship.
class HasOneThrough {
  /// Creates a [HasOneThrough] annotation.
  const HasOneThrough(
    this.related, {
    required this.through,
    this.firstKey,
    this.secondKey,
  });

  /// The final related model type.
  final Type related;

  /// The intermediate model type.
  final Type through;

  /// Key on the intermediate table.
  final String? firstKey;

  /// Key on the final related table.
  final String? secondKey;
}

/// Defines a has-many-through relationship.
class HasManyThrough {
  /// Creates a [HasManyThrough] annotation.
  const HasManyThrough(
    this.related, {
    required this.through,
    this.firstKey,
    this.secondKey,
  });

  /// The final related model type.
  final Type related;

  /// The intermediate model type.
  final Type through;

  /// Key on the intermediate table.
  final String? firstKey;

  /// Key on the final related table.
  final String? secondKey;
}

/// Defines a polymorphic one-to-one relationship.
class MorphOne {
  /// Creates a [MorphOne] annotation.
  const MorphOne(this.related, {this.morphName});

  /// The related model type.
  final Type related;

  /// Morph name used for type/id columns.
  final String? morphName;
}

/// Defines a polymorphic one-to-many relationship.
class MorphMany {
  /// Creates a [MorphMany] annotation.
  const MorphMany(this.related, {this.morphName});

  /// The related model type.
  final Type related;

  /// Morph name used for type/id columns.
  final String? morphName;
}

/// Defines the inverse of a polymorphic
/// relationship.
class MorphTo {
  /// Creates a [MorphTo] annotation.
  const MorphTo({this.types = const <String, Type>{}});

  /// Map of morph type strings to Dart types.
  final Map<String, Type> types;
}

/// Defines a polymorphic many-to-many
/// relationship.
class MorphToMany {
  /// Creates a [MorphToMany] annotation.
  const MorphToMany(this.related, {this.morphName, this.pivotTable});

  /// The related model type.
  final Type related;

  /// Morph name used for type/id columns.
  final String? morphName;

  /// Explicit pivot table name.
  final String? pivotTable;
}

/// Defines a local query scope.
class Scope {
  /// Creates a [Scope] annotation.
  const Scope(this.name);

  /// Scope method name.
  final String name;
}

/// Registers a global query scope.
class GlobalScope {
  /// Creates a [GlobalScope] annotation.
  const GlobalScope(this.scopeType);

  /// The global scope class type.
  final Type scopeType;
}

/// Marks a computed attribute as appended to
/// serialization output.
class Appended {
  /// Creates an [Appended] annotation.
  const Appended(this.name);

  /// The attribute name to append.
  final String name;
}

/// Hides a field from serialization output.
class Hidden {
  /// Creates a [Hidden] annotation.
  const Hidden();
}

/// Declares a virtual attribute accessor.
class Attribute {
  /// Creates an [Attribute] annotation.
  const Attribute(this.name);

  /// The virtual attribute name.
  final String name;
}

/// Assigns a cast to a model field.
class CastAs {
  /// Creates a [CastAs] annotation.
  const CastAs(this.castType);

  /// The cast class type.
  final Type castType;
}

/// Marks fields as mass-assignable.
class Fillable {
  /// Creates a [Fillable] annotation.
  const Fillable(this.fields);

  /// List of mass-assignable field names.
  final List<String> fields;
}

/// Marks fields as guarded from mass assignment.
class Guarded {
  /// Creates a [Guarded] annotation.
  const Guarded(this.fields);

  /// List of guarded field names.
  final List<String> fields;
}

/// Marks a method as a computed attribute.
class Computed {
  /// Creates a [Computed] annotation.
  const Computed(this.name);

  /// The computed attribute name.
  final String name;
}
