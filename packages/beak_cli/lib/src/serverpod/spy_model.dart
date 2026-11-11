/// One `relation(...)` option of a Serverpod field.
final class SpyRelation {
  /// Creates a relation option.
  const SpyRelation({
    this.parent,
    this.field,
    this.name,
    this.onDelete,
    this.optional = false,
  });

  /// `parent=<table>`: the field is the foreign key of that table.
  final String? parent;

  /// `field=<name>`: the scalar foreign key this relation reads.
  final String? field;

  /// `name=<name>`: the shared name that pairs the two sides.
  final String? name;

  /// `onDelete=<Action>`, as Serverpod spells it.
  final String? onDelete;

  /// The `optional` flag.
  final bool optional;
}

/// One field of a Serverpod model, as written.
final class SpyField {
  /// Creates a field.
  const SpyField({
    required this.name,
    required this.type,
    this.relation,
    this.scope,
    this.persist = true,
    this.defaultValue,
    this.hasDefault = false,
    this.column,
  });

  /// The field name.
  final String name;

  /// The type as written, nullability included (`String?`).
  final String type;

  /// The `relation` option, when the field has one.
  final SpyRelation? relation;

  /// `scope=...`, or `null` for the default (`all`).
  final String? scope;

  /// `false` for `!persist`.
  final bool persist;

  /// The `default=` text, as a Dart-compatible literal, or `null`.
  final String? defaultValue;

  /// Whether Serverpod or the database supplies a value when none is given
  /// (`default`, `defaultModel` or `defaultPersist`).
  final bool hasDefault;

  /// A `column=` override of the physical column name, or `null`.
  final String? column;

  /// Whether the type ends in `?`.
  bool get nullable => type.endsWith('?');

  /// The type without its `?`.
  String get baseType => nullable ? type.substring(0, type.length - 1) : type;

  /// The physical column name.
  String get columnName => column ?? name;

  /// Whether the field is a list (or set) type.
  bool get isCollection =>
      baseType.startsWith('List<') || baseType.startsWith('Set<');

  /// The element type of a `List<X>`, or `null`.
  String? get elementType => isCollection
      ? baseType.substring(baseType.indexOf('<') + 1, baseType.length - 1)
      : null;

  /// Whether the field is not sent to clients at all.
  bool get isServerOnly => scope == 'serverOnly' || scope == 'none';
}

/// One index of a Serverpod model.
final class SpyIndex {
  /// Creates an index.
  const SpyIndex({
    required this.name,
    required this.fields,
    this.unique = false,
  });

  /// The index name.
  final String name;

  /// The field names, in order.
  final List<String> fields;

  /// Whether it enforces uniqueness.
  final bool unique;
}

/// A Serverpod class, with or without a table.
final class SpyClass {
  /// Creates a class.
  const SpyClass({
    required this.name,
    required this.path,
    required this.fields,
    this.table,
    this.parent,
    this.indexes = const [],
    this.serverOnly = false,
  });

  /// The class name.
  final String name;

  /// The file it is declared in, relative to the server package.
  final String path;

  /// Its own fields, in declaration order (not the inherited ones).
  final List<SpyField> fields;

  /// The table name, or `null` for a model that is not persisted.
  final String? table;

  /// The `extends` class name, if any.
  final String? parent;

  /// Its declared indexes.
  final List<SpyIndex> indexes;

  /// Whether the class is `serverOnly: true`.
  final bool serverOnly;
}

/// One value of a Serverpod enum with its property values as Dart literals.
final class SpyEnumValue {
  /// Creates an enum value.
  const SpyEnumValue(this.name, this.properties);

  /// The value name, which is its wire name.
  final String name;

  /// One Dart literal per property, in the order of [SpyEnum.properties].
  final List<String> properties;
}

/// A Serverpod enum.
final class SpyEnum {
  /// Creates an enum.
  const SpyEnum({
    required this.name,
    required this.path,
    required this.values,
    this.properties = const {},
    this.serialized,
  });

  /// The enum name.
  final String name;

  /// The file it is declared in, relative to the server package.
  final String path;

  /// The values, in order.
  final List<SpyEnumValue> values;

  /// Property name to Dart type.
  final Map<String, String> properties;

  /// `serialized:` as written (`byName` or `byIndex`), or `null`.
  final String? serialized;
}

/// Every model and enum read from a Serverpod project.
final class SpyProject {
  /// Creates a project from its parsed declarations.
  const SpyProject({required this.classes, required this.enums});

  /// The classes by name.
  final Map<String, SpyClass> classes;

  /// The enums by name.
  final Map<String, SpyEnum> enums;

  /// The class with the table [table], or `null`.
  SpyClass? classOfTable(String table) {
    for (final spyClass in classes.values) {
      if (spyClass.table == table) return spyClass;
    }
    return null;
  }

  /// The fields of [spyClass] with the inherited ones first, so a child can
  /// redeclare a field of its parent.
  List<SpyField> fieldsOf(SpyClass spyClass) {
    final result = <String, SpyField>{};
    final chain = <SpyClass>[];
    for (
      SpyClass? current = spyClass;
      current != null && !chain.contains(current);
      current = classes[current.parent]
    ) {
      chain.insert(0, current);
    }
    for (final link in chain) {
      for (final field in link.fields) {
        result[field.name] = field;
      }
    }
    return result.values.toList();
  }

  /// The indexes of [spyClass] and the classes it extends.
  List<SpyIndex> indexesOf(SpyClass spyClass) => [
    for (
      SpyClass? current = spyClass;
      current != null;
      current = classes[current.parent]
    )
      ...current.indexes,
  ];
}
