/// Per-field presentation the inventory overrides.
final class InventoryField {
  /// Creates a field override.
  const InventoryField({
    this.label,
    this.min,
    this.max,
    this.maxLength,
    this.format,
    this.semantic,
    this.text = false,
    this.name,
  });

  /// The column label.
  final String? label;

  /// A lower bound (`BeakMin`) for a number column.
  final num? min;

  /// An upper bound (`BeakMax`) for a number column.
  final num? max;

  /// A length bound (`BeakMaxLength`) for a text column.
  final int? maxLength;

  /// The `BeakDateFormat` value name for a `DateTime` column.
  final String? format;

  /// The `BeakSemantic` constructor name (`email`, `url`, ...).
  final String? semantic;

  /// Whether a `String` column is multi-line text.
  final bool text;

  /// The Dart name to use for the field instead of the Serverpod one.
  final String? name;
}

/// The roles that override an area's, per operation.
final class InventoryAccess {
  /// Creates the overrides.
  const InventoryAccess({this.operations = const {}, this.actions = const {}});

  /// Operation name (`read`, `write`, `create`, `update`, `delete`) to the
  /// roles that must all be held.
  final Map<String, List<String>> operations;

  /// Command name to the roles that must all be held.
  final Map<String, List<String>> actions;
}

/// One admitted Serverpod model.
final class InventoryResource {
  /// Creates a resource.
  const InventoryResource({
    required this.name,
    required this.path,
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
    this.access = const InventoryAccess(),
    this.reason,
    this.restoreKey,
    this.fields = const {},
    this.labelKey,
  });

  /// The Serverpod class name.
  final String name;

  /// The inventory file that admits it.
  final String path;

  /// The area, from the resource or its file; `null` when neither names one.
  final String? area;

  /// The operations the model supports.
  final List<String> operations;

  /// The write binding, a value of `generate.writes`.
  final String? write;

  /// The reviewed write fields, or `null` when the key is absent.
  final List<String>? writeFields;

  /// Relations whose rows are saved with this one.
  final List<String> ownedRelations;

  /// Relations exposed only as their scalar foreign key.
  final List<String> scalarRelations;

  /// The field that names a record.
  final String? display;

  /// Fields not imported at all.
  final List<String> exclude;

  /// Columns that never leave the server.
  final List<String> hidden;

  /// Literal defaults of columns, as YAML scalars.
  final Map<String, Object?> defaults;

  /// Role overrides.
  final InventoryAccess access;

  /// Why writes are closed.
  final String? reason;

  /// The restore key, or `null` to detect it.
  final List<String>? restoreKey;

  /// Presentation overrides by field name.
  final Map<String, InventoryField> fields;

  /// The key the model's labels are found under in the label files, instead
  /// of its lowerCamelCase class name.
  final String? labelKey;

  /// Whether any operation besides `read` is open.
  bool get writes => operations.any((operation) => operation != 'read');
}

/// One field of a non-persisted command input.
final class InventoryInputField {
  /// Creates an input field.
  const InventoryInputField({
    this.belongsTo,
    this.foreignKey,
    this.type,
    this.required = true,
    this.label,
  });

  /// The model class the field selects, for a relation.
  final String? belongsTo;

  /// The foreign key column name, for a relation.
  final String? foreignKey;

  /// A scalar Dart type (`String`, `int`, `bool`, `double`, `DateTime`).
  final String? type;

  /// Whether the field must be filled.
  final bool required;

  /// The label, or `null` for the title-cased name.
  final String? label;
}

/// A command input model that is never persisted.
final class InventoryInput {
  /// Creates an input.
  const InventoryInput({
    required this.name,
    required this.path,
    required this.fields,
    this.table,
  });

  /// The class name.
  final String name;

  /// The inventory file that declares it.
  final String path;

  /// The input's fields by name.
  final Map<String, InventoryInputField> fields;

  /// The table name its model reports, or `null` for `input_<snake>`.
  final String? table;
}

/// Everything the inventory admits.
final class Inventory {
  /// Creates an inventory.
  const Inventory({required this.resources, required this.inputs});

  /// The admitted models by class name, in file order.
  final Map<String, InventoryResource> resources;

  /// The command inputs by class name.
  final Map<String, InventoryInput> inputs;

  /// The inventory files read, as paths relative to `beak.yaml`.
  List<String> get files => {
    for (final resource in resources.values) resource.path,
    for (final input in inputs.values) input.path,
  }.toList();
}
