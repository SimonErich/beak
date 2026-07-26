import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../common/beak_color.dart';
import '../context/beak_context.dart';
import '../relations/beak_on_delete.dart';
import '../rules/beak_rule.dart';
import '../storage/file_rules/beak_dimensions.dart';
import '../storage/file_rules/beak_file_type.dart';
import '../storage/transforms/beak_image_transform.dart';

/// Marker base for a declarative schema class.
///
/// A schema class is a *description*, never an instance: its fields are
/// `late final` with no constructor, so constructing one would throw on first
/// read. Extending this marker lets tooling say so, and makes the intent
/// obvious at the declaration site.
///
/// ```dart
/// @BeakResource(softDeletes: true, timestamps: true)
/// final class Product extends BeakSchema {
///   @Display()
///   @Column(searchable: true, rules: [BeakMaxLength(255)])
///   late final String name;
///
///   @Column(prefix: '€', rules: [BeakMin(0)])
///   late final double price;
///
///   @BelongsTo()
///   late final Category? category;
/// }
/// ```
///
/// `beak prepare` reads this and generates `ProductColumns`,
/// `ProductRelations`, `ProductModel` and `ProductRecord` into a part file.
@immutable
abstract base class BeakSchema {
  /// Enables `const` construction by subclasses. Never actually construct one.
  const BeakSchema();
}

/// Declares a class as a Beak resource.
///
/// The class name drives the defaults: `Product` becomes the `products`
/// table and the `ProductModel`/`ProductColumns` symbols.
@immutable
final class BeakResource {
  /// Declares the annotated class a resource.
  const BeakResource({
    this.table,
    this.softDeletes = false,
    this.timestamps = false,
    this.managesSchema = true,
  });

  /// Physical table name. Defaults to the pluralised, snake-cased class name.
  final String? table;

  /// Whether deletes write a `deleted_at` marker instead of removing the row.
  final bool softDeletes;

  /// Whether to add `created_at` and `updated_at` columns.
  final bool timestamps;

  /// Whether Beak owns this resource's schema.
  ///
  /// Set `false` when another system already migrates the table — a
  /// Serverpod model, or a database Beak was pointed at rather than created.
  /// Migration generation skips it; everything else works the same.
  final bool managesSchema;
}

/// Configures the column a field becomes.
///
/// The field's Dart type selects the column *kind*; this only carries what
/// the type cannot express. Nullability decides required-ness: a non-nullable
/// field gets [BeakRequired], a nullable one does not.
@immutable
final class Column {
  /// Configures the annotated field's column.
  const Column({
    this.columnName,
    this.label,
    this.visibleOn,
    this.sortable = false,
    this.searchable = false,
    this.filterable = false,
    this.rules = const [],
    this.prefix,
    this.suffix,
    this.precision,
    this.min,
    this.max,
    this.maxLength,
    this.format,
  });

  /// Storage column name. Defaults to the snake-cased field name.
  final String? columnName;

  /// Human-readable label. Defaults to the title-cased field name.
  final String? label;

  /// Surfaces this column appears on. Defaults to table, form and detail.
  final Set<BeakContext>? visibleOn;

  /// Whether table views may sort by this column.
  final bool sortable;

  /// Whether search includes this column.
  final bool searchable;

  /// Whether table views may filter by this column.
  final bool filterable;

  /// Validation rules, enforced on both the client and the API.
  final List<BeakRule> rules;

  /// Currency or unit prefix, for numeric columns.
  final String? prefix;

  /// Unit suffix, for numeric columns.
  final String? suffix;

  /// Decimal places, for a `double` field.
  final int? precision;

  /// Lowest accepted value, for an `int` field.
  final int? min;

  /// Highest accepted value, for an `int` field.
  final int? max;

  /// Longest accepted text, for a `String` field.
  final int? maxLength;

  /// Rendering format, for a `DateTime` field.
  final BeakDateFormat? format;
}

/// Marks the field that represents a record in pickers, links and titles.
///
/// Exactly one field per schema carries it; without one, Beak falls back to
/// the first string field.
@immutable
final class Display {
  /// Marks the annotated field as the display column.
  const Display();
}

/// Declares an image column, with its storage and transform rules.
///
/// Apply to a `BeakImageRef` field.
@immutable
final class Image {
  /// Declares the annotated field an image column stored under
  /// [storagePath].
  const Image({
    required this.storagePath,
    this.maxSizeInBytes,
    this.allowedTypes = const [],
    this.maxDimensions,
    this.aspectRatio,
    this.thumbnail,
    this.transforms = const [],
  });

  /// Storage subfolder uploads land in.
  final String storagePath;

  /// Highest accepted upload size.
  final int? maxSizeInBytes;

  /// Accepted upload types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;

  /// Largest accepted dimensions.
  final BeakDimensions? maxDimensions;

  /// Required width-to-height ratio.
  final double? aspectRatio;

  /// Thumbnail size to render in tables.
  final BeakDimensions? thumbnail;

  /// Transforms run on upload, in order.
  final List<BeakImageTransform> transforms;
}

/// Declares a file column. Apply to a `BeakFileRef` field.
@immutable
final class FileField {
  /// Declares the annotated field a file column stored under [storagePath].
  const FileField({
    required this.storagePath,
    this.maxSizeInBytes,
    this.allowedTypes = const [],
  });

  /// Storage subfolder uploads land in.
  final String storagePath;

  /// Highest accepted upload size.
  final int? maxSizeInBytes;

  /// Accepted upload types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;
}

/// Assigns a badge colour to each value of an enum field.
///
/// Generic so the map's keys are checked against *this* field's enum rather
/// than degrading to `Map<Enum, BeakColor>`.
@immutable
final class Badges<T extends Enum> {
  /// Assigns badge colours for the annotated enum field.
  const Badges(this.colors);

  /// Badge colour per value; unmapped values use the theme default.
  final Map<T, BeakColor> colors;
}

/// Declares an opaque column rendered by a client-registered builder.
///
/// Apply to an `Object` field.
@immutable
final class Custom {
  /// Declares the annotated field a custom column identified by [tag].
  const Custom(this.tag);

  /// Tag the frontend's cell-renderer registry is keyed by.
  final String tag;
}

/// A child-side to-one relationship: this table holds the foreign key.
///
/// Apply to a field whose type is another schema class. The foreign-key
/// column is synthesised — declaring it separately would be the same fact
/// written twice.
@immutable
final class BelongsTo {
  /// Declares the annotated field a belongs-to relationship.
  const BelongsTo({
    this.foreignKey,
    this.onDelete = BeakOnDelete.setNull,
    this.inverse = true,
  });

  /// Foreign-key column. Defaults to the snake-cased field name plus `_id`.
  final String? foreignKey;

  /// What happens to this row when the related record is deleted.
  final BeakOnDelete onDelete;

  /// Whether to generate the matching has-many on the other side.
  ///
  /// Set `false` for a lookup table that should not gain a back-reference to
  /// everything pointing at it.
  final bool inverse;
}

/// A parent-side to-one relationship: the *other* table holds the key.
@immutable
final class HasOne {
  /// Declares the annotated field a has-one relationship.
  const HasOne({this.foreignKey});

  /// Foreign-key column on the related table. Defaults to this table's
  /// singular name plus `_id`.
  final String? foreignKey;
}

/// A parent-side to-many relationship. Apply to a `List<Other>` field.
@immutable
final class HasMany {
  /// Declares the annotated field a has-many relationship.
  const HasMany({this.foreignKey, this.onDelete = BeakOnDelete.restrict});

  /// Foreign-key column on the related table.
  final String? foreignKey;

  /// What happens to the children when this row is deleted.
  final BeakOnDelete onDelete;
}

/// A many-to-many relationship through a pivot table.
///
/// Apply to a `List<Other>` field. The pivot table and both key columns are
/// derived from the two table names unless given.
@immutable
final class BelongsToMany {
  /// Declares the annotated field a many-to-many relationship.
  const BelongsToMany({
    this.pivotTable,
    this.foreignPivotKey,
    this.relatedPivotKey,
    this.allowCreate = false,
    this.maxAllowed,
    this.onDelete = BeakOnDelete.cascade,
    this.inverse = true,
  });

  /// Join table. Defaults to the two singular table names, sorted, joined by
  /// an underscore.
  final String? pivotTable;

  /// Pivot column pointing at this table.
  final String? foreignPivotKey;

  /// Pivot column pointing at the related table.
  final String? relatedPivotKey;

  /// Whether the relation manager may create related records inline.
  final bool allowCreate;

  /// Highest number of related records allowed.
  final int? maxAllowed;

  /// What happens to the pivot rows when this row is deleted.
  final BeakOnDelete onDelete;

  /// Whether to generate the mirrored relationship on the other side.
  final bool inverse;
}
