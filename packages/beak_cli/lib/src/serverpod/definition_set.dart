/// What a definition class says about one exposed field, beyond Serverpod.
final class DefinitionResourceField {
  /// Creates a field override.
  const DefinitionResourceField({
    this.label,
    this.arguments = const {},
    this.doc,
    this.relation,
  });

  /// The column or relationship label.
  final String? label;

  /// `@Column(...)` arguments as source, laid over the generated ones.
  final Map<String, String> arguments;

  /// The field's doc comment.
  final String? doc;

  /// The relationship annotation (`belongsTo`, `hasOne`, `hasMany`), or
  /// `null` for a column.
  final String? relation;
}

/// The roles that override an area's, per operation.
final class DefinitionAccess {
  /// Creates the overrides.
  const DefinitionAccess({this.operations = const {}});

  /// Roles per operation (`read`, `write`, `create`, `update`, `delete`).
  final Map<String, List<String>> operations;
}

/// One exposed Serverpod model, as its definition class declares it.
final class DefinitionResource {
  /// Creates a resource.
  const DefinitionResource({
    required this.name,
    required this.path,
    required this.library,
    this.area,
    this.operations = const ['read'],
    this.write,
    this.writeFields,
    this.ownedRelations = const [],
    this.scalarRelations = const [],
    this.display,
    this.exclude = const [],
    this.hidden = const [],
    this.defaults = const {},
    this.access = const DefinitionAccess(),
    this.reason,
    this.restoreKey,
    this.fields = const {},
    this.labelKey,
    this.hasBehavior = false,
    this.hasValidationRules = false,
    this.hasPermissions = false,
    this.docComment,
  });

  /// The Serverpod class name.
  final String name;

  /// The definition file, as issues name it.
  final String path;

  /// The definition library under `lib/`, which the part belongs to.
  final String library;

  /// The `generate.areas` entry.
  final String? area;

  /// The offered operations (`read`, `create`, `update`, `delete`).
  final List<String> operations;

  /// The write binding value name.
  final String? write;

  /// The fields a write may set.
  final List<String>? writeFields;

  /// Has-many relations saved with the record.
  final List<String> ownedRelations;

  /// Relations exposed only as their foreign key.
  final List<String> scalarRelations;

  /// The display field.
  final String? display;

  /// Serverpod fields the class does not declare.
  final List<String> exclude;

  /// Fields kept on the server.
  final List<String> hidden;

  /// Values a create writes into hidden fields.
  final Map<String, Object?> defaults;

  /// Per-operation role overrides.
  final DefinitionAccess access;

  /// Why writes are closed.
  final String? reason;

  /// The restore key of a soft-deleted row.
  final List<String>? restoreKey;

  /// Per-field labels, arguments and docs.
  final Map<String, DefinitionResourceField> fields;

  /// The label-file key of the model.
  final String? labelKey;

  /// Whether the class declares `static get behavior`.
  final bool hasBehavior;

  /// Whether the class declares `static get validationRules`.
  final bool hasValidationRules;

  /// Whether the class declares `static get permissions`.
  final bool hasPermissions;

  /// The class's doc comment.
  final String? docComment;

  /// Whether any write is offered.
  bool get writes => operations.any((operation) => operation != 'read');
}

/// One field of a command input.
final class DefinitionInputField {
  /// Creates an input field.
  const DefinitionInputField({
    this.belongsTo,
    this.foreignKey,
    this.type,
    this.required = true,
    this.label,
  });

  /// The model a relation field points at.
  final String? belongsTo;

  /// The key a relation field stores.
  final String? foreignKey;

  /// The Dart type of a scalar field.
  final String? type;

  /// Whether a value is required.
  final bool required;

  /// The field label.
  final String? label;
}

/// A non-persisted command input.
final class DefinitionInput {
  /// Creates an input.
  const DefinitionInput({
    required this.name,
    required this.path,
    required this.library,
    required this.fields,
    this.table,
  });

  /// The class name.
  final String name;

  /// The definition file, as issues name it.
  final String path;

  /// The definition library under `lib/`.
  final String library;

  /// The fields, by name.
  final Map<String, DefinitionInputField> fields;

  /// The table name its model reports.
  final String? table;
}

/// Every exposed model and command input.
final class DefinitionSet {
  /// Creates a definition set.
  const DefinitionSet({required this.resources, required this.inputs});

  /// The exposed models, by Serverpod class name.
  final Map<String, DefinitionResource> resources;

  /// The command inputs, by class name.
  final Map<String, DefinitionInput> inputs;
}
