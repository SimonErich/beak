import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../columns/beak_semantic.dart';
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
/// @Resource(softDeletes: true, timestamps: true)
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
/// `beak prepare` reads this and generates the rest into a
/// `product.beak.dart` part: `ProductModel`, whose static field references
/// (`ProductModel.name`, `ProductModel.category`) are what panel code
/// configures tables, forms and filters with; the `ProductColumns` and
/// `ProductRelations` constants migrations build from; and the typed
/// `record.asProduct` and `draft.asProduct` views.
///
/// The model may take shared rules from static getters on the class, which
/// the generator forwards: `validationRules`, `behavior`, `permissions` and
/// `capabilities`.
///
/// ```dart
/// static BeakPermissions get permissions => const BeakPermissions.allowAll();
/// ```
@immutable
abstract base class BeakSchema {
  /// Enables `const` construction by subclasses. Never actually construct one.
  const BeakSchema();
}

/// Declares a class as a Beak resource.
///
/// The class name drives the defaults: `Product` becomes the `products`
/// table and the `ProductModel`/`ProductColumns` symbols.
///
/// Named without the `Beak` prefix, like every annotation in this library:
/// a model file's imports are `package:beak/beak.dart` for the generated part
/// and `package:beak/schema.dart` for the annotations, and `BeakResource` is
/// already the panel-side resource config in the first of those.
@immutable
final class Resource {
  /// Declares the annotated class a resource.
  const Resource({
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
///
/// Bounds are rules, declared once: `rules: [BeakMaxLength(120)]` on a
/// `String` field validates the input *and* sizes the stored column, and
/// `rules: [BeakMin(0), BeakMax(10)]` on an `int` field validates and bounds
/// the form's stepper.
///
/// ```dart
/// @Column(searchable: true, rules: [BeakMaxLength(120)])
/// late final String name;
/// ```
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
    this.indexed = false,
    this.unique = false,
    this.rules = const [],
    this.prefix,
    this.suffix,
    this.precision,
    this.totalDigits,
    this.format,
    this.placeholder,
    this.trueLabel,
    this.falseLabel,
    this.defaultValue,
    this.semantic,
    this.currencyFrom,
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

  /// Whether the database should index this column.
  ///
  /// The generated migration creates the index, so declaring it here is the
  /// whole of it. Every belongs-to foreign key is indexed without being
  /// asked, so this is for the columns a project sorts or filters by often.
  final bool indexed;

  /// Whether the database should enforce that this column's values are
  /// distinct — a unique index, so it indexes too.
  final bool unique;

  /// Validation rules, enforced on both the client and the API.
  ///
  /// `BeakMaxLength` on a `String` field also sets the stored column length,
  /// and `BeakMin`/`BeakMax` on an `int` field also bound the form input, so
  /// a limit is written once and means the same thing everywhere.
  final List<BeakRule> rules;

  /// Currency or unit prefix, for numeric columns.
  final String? prefix;

  /// Unit suffix, for numeric columns.
  final String? suffix;

  /// Decimal places, for a `double` field.
  ///
  /// Displayed and stored: the generated migration uses it as the column's
  /// SQL scale.
  final int? precision;

  /// Total stored digits, for a `double` field.
  ///
  /// The SQL precision of `NUMERIC(totalDigits, precision)`; defaults to 10.
  final int? totalDigits;

  /// Rendering format, for a `DateTime` field.
  final BeakDateFormat? format;

  /// Hint text shown in the empty input, for a `String` field.
  final String? placeholder;

  /// Label for the true state, for a `bool` field.
  final String? trueLabel;

  /// Label for the false state, for a `bool` field.
  final String? falseLabel;

  /// The default value used for a new record when the field is omitted.
  ///
  /// Must match the declared field type and be a constant expression.
  final Object? defaultValue;

  /// Domain semantics inferred from the declared type unless overridden.
  final BeakSemantic? semantic;

  /// Schema member holding a money amount's currency, for example `#currency`.
  /// The generator resolves this symbol to a typed column and rejects typos.
  final Symbol? currencyFrom;
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

/// Assigns display labels to an enum field without changing stored values.
///
/// ```dart
/// @EnumLabels<OrderStatus>({OrderStatus.inKitchen: 'In kitchen'})
/// late final OrderStatus status;
/// ```
@immutable
final class EnumLabels<T extends Enum> {
  /// Maps typed enum values to their display labels.
  const EnumLabels(this.labels);

  /// Unmapped values retain their enum name.
  final Map<T, String> labels;
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
    this.label,
    this.foreignKey,
    this.searchOn = const <Symbol>[],
    this.onDelete = BeakOnDelete.setNull,
    this.inverse = true,
  });

  /// Human-readable label. Defaults to the title-cased field name.
  ///
  /// Also labels the foreign-key column this relationship owns, so a picker
  /// reading "Customer" is not filed under "User".
  final String? label;

  /// Fields of the related schema the picker searches, as symbols.
  ///
  /// Defaults to the related model's display column. Widen it when a person
  /// looks a record up by something other than its name — an email, a
  /// reference number:
  ///
  /// ```dart
  /// @BelongsTo(searchOn: [#email, #lastName])
  /// late final User customer;
  /// ```
  ///
  /// Each symbol names a field of the related schema class, and the
  /// generator resolves it to that field's column, so a typo is an error
  /// naming the field rather than a picker that finds nothing.
  final List<Symbol> searchOn;

  /// Foreign-key column. Defaults to the snake-cased field name plus `_id`.
  final String? foreignKey;

  /// What happens to this row when the related record is deleted.
  ///
  /// When omitted, generation uses `setNull` for a nullable relationship and
  /// `restrict` for a non-nullable relationship. An explicit value wins.
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
  const HasOne({this.label, this.foreignKey, this.owned = false});

  /// Whether the related record belongs exclusively to the parent.
  final bool owned;

  /// Human-readable label. Defaults to the title-cased field name.
  final String? label;

  /// Foreign-key column on the related table. Defaults to this table's
  /// singular name plus `_id`.
  final String? foreignKey;
}

/// A parent-side to-many relationship. Apply to a `List<Other>` field.
@immutable
final class HasMany {
  /// Declares the annotated field a has-many relationship.
  const HasMany({
    this.label,
    this.foreignKey,
    this.onDelete = BeakOnDelete.restrict,
    this.owned = false,
  });

  /// Human-readable label. Defaults to the title-cased field name.
  final String? label;

  /// Foreign-key column on the related table.
  final String? foreignKey;

  /// What happens to the children when this row is deleted.
  final BeakOnDelete onDelete;

  /// Whether related records belong exclusively to the parent.
  final bool owned;
}

/// A many-to-many relationship through a pivot table.
///
/// Apply to a `List<Other>` field. The pivot table and both key columns are
/// derived from the two table names unless given.
@immutable
final class BelongsToMany {
  /// Declares the annotated field a many-to-many relationship.
  const BelongsToMany({
    this.label,
    this.pivotTable,
    this.foreignPivotKey,
    this.relatedPivotKey,
    this.searchOn = const <Symbol>[],
    this.allowCreate = false,
    this.maxAllowed,
    this.onDelete = BeakOnDelete.cascade,
    this.inverse = true,
  });

  /// Human-readable label. Defaults to the title-cased field name.
  final String? label;

  /// Fields of the related schema the picker searches, as symbols such as
  /// `#name`.
  ///
  /// Defaults to the related model's display column. Checked against the
  /// related schema like [BelongsTo.searchOn].
  final List<Symbol> searchOn;

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
