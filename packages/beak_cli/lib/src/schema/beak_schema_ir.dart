/// The column kinds a schema field can become.
///
/// Selected by the field's declared Dart type, never by a discriminator the
/// user writes.
enum BeakColumnKind {
  /// `String` — a single-line value.
  string('BeakStringColumn'),

  /// `BeakText` — a multi-line value.
  text('BeakTextColumn'),

  /// `BeakRichText` — HTML or Markdown.
  richText('BeakRichTextColumn'),

  /// `int`.
  integer('BeakIntColumn'),

  /// `double`.
  decimal('BeakDecimalColumn'),

  /// `bool`.
  boolean('BeakBoolColumn'),

  /// `DateTime`.
  dateTime('BeakDateTimeColumn'),

  /// An enum declared in the project.
  enumeration('BeakEnumColumn'),

  /// `BeakJson`.
  json('BeakJsonColumn'),

  /// `BeakHexColor`.
  color('BeakColorColumn'),

  /// `BeakImageRef`.
  image('BeakImageColumn'),

  /// `BeakFileRef`.
  file('BeakFileColumn'),

  /// An `Object` field carrying `@Custom`.
  custom('BeakCustomColumn');

  const BeakColumnKind(this.columnType);

  /// The `BeakColumn` subclass this kind emits.
  final String columnType;

  /// The kind a field declared as [typeName] becomes, or `null` when the type
  /// names something else (a relationship, or an unsupported type).
  // --8<-- [start:beakColumnKindOfType]
  static BeakColumnKind? ofType(String typeName) => switch (typeName) {
    'String' || 'BeakDate' || 'BeakTime' => string,
    'BeakText' => text,
    'BeakRichText' => richText,
    'int' || 'Duration' || 'BeakDecimal' => integer,
    'double' => decimal,
    'bool' => boolean,
    'DateTime' => dateTime,
    'BeakJson' || 'BeakJsonObject' => json,
    'BeakHexColor' => color,
    'BeakImageRef' => image,
    'BeakFileRef' => file,
    _ => null,
  };
  // --8<-- [end:beakColumnKindOfType]
}

/// The relationship kinds a schema field can become.
enum BeakRelationKind {
  /// This table holds the foreign key.
  belongsTo('BeakBelongsTo'),

  /// The related table holds the foreign key; at most one.
  hasOne('BeakHasOne'),

  /// The related table holds the foreign key; many.
  hasMany('BeakHasMany'),

  /// Through a pivot table.
  belongsToMany('BeakBelongsToMany');

  const BeakRelationKind(this.relationType);

  /// The `BeakRelationship` subclass this kind emits.
  final String relationType;
}

/// One column, as read from a schema field.
///
/// Annotation arguments are kept as *source text* rather than evaluated
/// values. The generator re-emits them verbatim, so anything valid in a
/// `const` expression works — a rule list, a nested transform, an enum
/// constant — without the generator having to model each one.
final class BeakColumnIr {
  /// Creates a column description.
  const BeakColumnIr({
    required this.fieldName,
    required this.columnKey,
    required this.label,
    required this.kind,
    required this.isRequired,
    this.enumTypeName,
    this.declaredValueType,
    this.arguments = const {},
    this.docComment,
    this.omitFromValues = false,
  });

  /// The Dart field this column came from.
  final String fieldName;

  /// Storage column name.
  final String columnKey;

  /// Human-readable label.
  final String label;

  /// Which `BeakColumn` subclass to emit.
  final BeakColumnKind kind;

  /// Whether the field was non-nullable, and so carries `BeakRequired`.
  final bool isRequired;

  /// For [BeakColumnKind.enumeration], the enum's Dart type name.
  final String? enumTypeName;

  /// Semantic Dart type when it differs from its physical column reader.
  final String? declaredValueType;

  /// Extra named arguments, as source text, keyed by parameter name.
  final Map<String, String> arguments;

  /// The field's own doc comment, carried onto the generated constant.
  final String? docComment;

  /// Whether the constant is emitted but kept out of `columns`.
  ///
  /// A relation foreign key needs a column constant the admission can name,
  /// yet must not become a model column: the relation picker owns that value,
  /// and a second raw input would edit the same storage twice.
  final bool omitFromValues;

  /// Whether `@Column(unique: true)` was declared.
  ///
  /// Read through a getter rather than by indexing [arguments] at each call
  /// site, so the option's spelling lives in one place.
  bool get isUnique => arguments['unique'] == 'true';

  /// Whether the field declares a value for rows that do not supply one.
  bool get hasDefault =>
      arguments.containsKey('defaultValue') &&
      arguments['defaultValue'] != 'null';

  /// The Dart type this column reads its values as.
  String get valueType =>
      declaredValueType ??
      switch (kind) {
        BeakColumnKind.integer => 'int',
        BeakColumnKind.decimal => 'double',
        BeakColumnKind.boolean => 'bool',
        BeakColumnKind.dateTime => 'DateTime',
        BeakColumnKind.enumeration => enumTypeName!,
        BeakColumnKind.custom => 'Object',
        _ => 'String',
      };
}

/// One relationship, as read from a schema field.
final class BeakRelationIr {
  /// Creates a relationship description.
  const BeakRelationIr({
    required this.fieldName,
    required this.key,
    required this.label,
    required this.kind,
    required this.relatedSchema,
    this.searchOn = const <String>[],
    this.foreignKey,
    this.pivotTable,
    this.foreignPivotKey,
    this.relatedPivotKey,
    this.arguments = const {},
    this.docComment,
    this.generateInverse = true,
    this.isRequired = false,
  });

  /// The Dart field this relationship came from.
  final String fieldName;

  /// Relationship key, matching the ORM relation name.
  final String key;

  /// Human-readable label.
  final String label;

  /// Which `BeakRelationship` subclass to emit.
  final BeakRelationKind kind;

  /// Class name of the schema on the other side.
  final String relatedSchema;

  /// Fields of the related schema a picker searches, by Dart field name.
  ///
  /// Read from `searchOn: [#email]`, and resolved to column keys only when
  /// emitted, against the related schema. Empty means "the related model's
  /// display column", which is what a picker wants unless a person looks
  /// records up by something else.
  final List<String> searchOn;

  /// Foreign-key column, when the kind has one.
  final String? foreignKey;

  /// Pivot table, for a many-to-many.
  final String? pivotTable;

  /// Pivot column pointing at the owning table.
  final String? foreignPivotKey;

  /// Pivot column pointing at the related table.
  final String? relatedPivotKey;

  /// Extra named arguments, as source text.
  final Map<String, String> arguments;

  /// The field's own doc comment.
  final String? docComment;

  /// Whether the other side gets the mirrored relationship.
  final bool generateInverse;

  /// Whether the schema declares a non-nullable to-one relationship.
  final bool isRequired;
}

/// One resource, as read from a schema class.
final class BeakSchemaIr {
  /// Creates a schema description.
  const BeakSchemaIr({
    required this.className,
    required this.table,
    required this.libraryPath,
    required this.columns,
    required this.relations,
    required this.displayColumnKey,
    required this.softDeletes,
    required this.timestamps,
    required this.managesSchema,
    this.createdAtColumnKey = 'created_at',
    this.updatedAtColumnKey = 'updated_at',
    this.deletedAtColumnKey = 'deleted_at',
    this.isDeletedColumnKey,
    this.hasValidationRules = false,
    this.hasBehavior = false,
    this.hasPermissions = false,
    this.hasCapabilities = false,
    this.docComment,
  });

  /// The annotated class's name.
  final String className;

  /// Physical table name.
  final String table;

  /// Path of the declaring library, relative to `lib/`.
  final String libraryPath;

  /// Columns, in declaration order.
  final List<BeakColumnIr> columns;

  /// Relationships, in declaration order.
  final List<BeakRelationIr> relations;

  /// Key of the column representing a record.
  final String displayColumnKey;

  /// Whether deletes write a marker.
  final bool softDeletes;

  /// Whether the schema carries created/updated stamps.
  final bool timestamps;

  /// Physical creation timestamp key.
  final String createdAtColumnKey;

  /// Physical revision timestamp key.
  final String updatedAtColumnKey;

  /// Physical soft-delete timestamp key.
  final String deletedAtColumnKey;

  /// Optional boolean visibility flag.
  final String? isDeletedColumnKey;

  /// Whether Beak owns this resource's schema.
  final bool managesSchema;

  /// Whether the schema supplies a static record-validation rule getter.
  final bool hasValidationRules;

  /// Whether the schema supplies a static shared model-behavior getter.
  final bool hasBehavior;

  /// Whether the schema supplies `static BeakPermissions get permissions`.
  final bool hasPermissions;

  /// Whether the schema supplies `static Set<BeakOperation> get capabilities`.
  final bool hasCapabilities;

  /// The class's own doc comment.
  final String? docComment;

  /// Generated columns-class name.
  String get columnsClass => '${className}Columns';

  /// Generated relations-class name.
  String get relationsClass => '${className}Relations';

  /// Generated model-class name.
  String get modelClass => '${className}Model';

  /// Generated typed-record name.
  String get recordClass => '${className}Record';
}

/// The reviewed write admission of one generated model.
final class BeakAdmissionIr {
  /// Creates an admission.
  const BeakAdmissionIr({
    this.writable = const [],
    this.hidden = const [],
    this.restoreKey = const [],
    this.writeValue,
    this.reason,
    this.translationOwner,
    this.translationLocale,
  });

  /// Field names a client may write.
  final List<String> writable;

  /// Field names that never leave the server.
  final List<String> hidden;

  /// Field names re-creating a soft-deleted row restores by.
  final List<String> restoreKey;

  /// The generated write-binding value, as Dart source, or `null`.
  final String? writeValue;

  /// Why writes are closed, for a read-only model.
  final String? reason;

  /// The owner foreign-key field of a translation table, if any.
  final String? translationOwner;

  /// The locale field of a translation table, if any.
  final String? translationLocale;
}

/// The role-based access a generated model declares.
final class BeakPermissionsIr {
  /// Creates permissions.
  const BeakPermissionsIr({
    this.read = const [],
    this.write = const [],
    this.create,
    this.update,
    this.delete,
  });

  /// Roles that must all be held to read.
  final List<String> read;

  /// Roles that must all be held to write.
  final List<String> write;

  /// Roles for create, when narrower than [write].
  final List<String>? create;

  /// Roles for update, when narrower than [write].
  final List<String>? update;

  /// Roles for delete, when narrower than [write].
  final List<String>? delete;
}

/// One generated model: its schema plus the reviewed facts the inventory adds.
final class BeakGeneratedModel {
  /// Creates a generated model.
  const BeakGeneratedModel({
    required this.schema,
    required this.capabilities,
    required this.permissions,
    this.admission = const BeakAdmissionIr(),
  });

  /// Columns, relationships and table metadata.
  final BeakSchemaIr schema;

  /// The operations the panel may offer, by `BeakOperation` value name.
  final Set<String> capabilities;

  /// Who may do what.
  final BeakPermissionsIr permissions;

  /// The write admission.
  final BeakAdmissionIr admission;
}

/// One value of a generated enum.
final class BeakGeneratedEnumValue {
  /// Creates a value with its property literals.
  const BeakGeneratedEnumValue(this.name, this.properties);

  /// The wire name.
  final String name;

  /// One Dart literal per property, in [BeakGeneratedEnum.properties] order.
  final List<String> properties;
}

/// A Serverpod enum emitted as a standalone Dart enum.
final class BeakGeneratedEnum {
  /// Creates an enum.
  const BeakGeneratedEnum({
    required this.name,
    required this.values,
    this.properties = const {},
  });

  /// The enum name.
  final String name;

  /// The values, in order.
  final List<BeakGeneratedEnumValue> values;

  /// Property name to Dart type.
  final Map<String, String> properties;
}

/// A non-persisted command input model.
final class BeakGeneratedInput {
  /// Creates an input model.
  const BeakGeneratedInput(this.schema);

  /// Its columns and relationships.
  final BeakSchemaIr schema;
}
