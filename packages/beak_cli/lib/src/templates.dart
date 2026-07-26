import 'field_spec.dart';

/// Returns the Dart source of the canonical worm model for [resourceName].
///
/// The generated `final class extends Model` follows every worm convention
/// by hand (no codegen `part`): the [tableNameOf]-derived `tableName`
/// override, a typed constructor and `fromRow` hydration factory, a typed
/// getter per field in [fields], `toRow`, the `static query()` builder, and
/// the `$` field-companion class exposing worm `Field` constants. Pair it
/// with [generateMigration] and [generateBeakColumns] for a full resource.
///
/// ```dart
/// final specs = BeakFieldSpec.parseList('name:string,price:decimal');
/// final source = generateWormModel('Product', specs);
/// // source declares `final class Product extends Model`,
/// // `static QueryBuilder<Product> query()`, and `abstract final class
/// // Product$` with typed field constants.
/// ```
String generateWormModel(String resourceName, List<BeakFieldSpec> fields) {
  final String table = tableNameOf(resourceName);
  final String companion = '$resourceName\$';
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:beak/migrations.dart';")
    ..writeln()
    ..writeln('/// The $table worm model (canonical shape, no codegen).')
    ..writeln("@Table(name: '$table')")
    ..writeln('final class $resourceName extends Model {')
    ..writeln('  /// Creates a new, unsaved record.')
    ..write('  $resourceName({required String id')
    ..write(
      [
        for (final field in fields)
          ', required ${_dartTypeOf(field.kind)} ${field.camelName}',
      ].join(),
    )
    ..writeln('}) {')
    ..writeln("    setAttribute('id', id);")
    ..write(
      [
        for (final field in fields)
          "    setAttribute('${field.name}', ${field.camelName});\n",
      ].join(),
    )
    ..writeln('  }')
    ..writeln()
    ..writeln('  $resourceName._();')
    ..writeln()
    ..writeln('  /// Hydrates a persisted row.')
    ..writeln('  factory $resourceName.fromRow(Map<String, Object?> row) {')
    ..writeln('    final model = $resourceName._();')
    ..writeln('    row.forEach(model.hydrateAttribute);')
    ..writeln('    return model..markPersisted();')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  String get tableName => $companion.tableName;')
    ..writeln()
    ..writeln('  @override')
    ..writeln("  Object get id => getAttribute('id') ?? '';")
    ..writeln();
  for (final field in fields) {
    out
      ..writeln('  /// The `${field.name}` column.')
      ..writeln(
        '  ${_dartTypeOf(field.kind)} get ${field.camelName} => '
        'switch (getAttribute(\'${field.name}\')) {',
      )
      ..writeln('    final ${_dartTypeOf(field.kind)} value => value,')
      ..writeln('    _ => ${_fallbackOf(field.kind)},')
      ..writeln('  };')
      ..writeln();
  }
  out
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toRow() => {')
    ..writeln("    'id': id,")
    ..write(
      [for (final field in fields) "    '${field.name}': ${field.camelName},\n"]
          .join(),
    )
    ..writeln('  };')
    ..writeln()
    ..writeln('  /// A typed query over $table.')
    ..writeln('  static QueryBuilder<$resourceName> query() =>')
    ..writeln('      QueryBuilder<$resourceName>.from(')
    ..writeln('        QueryContext<$resourceName>(')
    ..writeln('          adapter: Worm.adapter(),')
    ..writeln('          table: $companion.tableName,')
    ..writeln('          hydrate: $resourceName.fromRow,')
    ..writeln('        ),')
    ..writeln('      );')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Typed field companions of [$resourceName].')
    ..writeln('abstract final class $companion {')
    ..writeln('  /// Physical table name.')
    ..writeln("  static const String tableName = '$table';")
    ..writeln();
  for (final field in fields) {
    out
      ..writeln('  /// The `${field.name}` column.')
      ..writeln(
        "  static const ${_wormFieldTypeOf(field.kind)} ${field.camelName} = "
        "${_wormFieldTypeOf(field.kind)}('${field.name}');",
      )
      ..writeln();
  }
  out.writeln('}');
  return out.toString();
}

/// Returns the Dart source of the worm migration that creates
/// [resourceName]'s table.
///
/// The generated `Migration` subclass creates the [tableNameOf] table with
/// a UUID primary key, one blueprint column per field in [fields], and
/// `timestamps()`, and drops it on `downSchema`. The [timestamp] prefixes
/// the migration's `name` (worm applies migrations in name order), so pass
/// a stable, sortable value such as `20260703_120000`. `beak prepare`
/// discovers the class under `lib/migrations/` and lists it on the generated
/// host; migrations are still never auto-applied — run `beak migrate`.
///
/// ```dart
/// final specs = BeakFieldSpec.parseList('name:string,price:decimal');
/// final source = generateMigration(
///   'Product',
///   specs,
///   timestamp: '20260703_120000',
/// );
/// // source declares `final class CreateProductsTable extends Migration`
/// // with name '20260703_120000_create_products_table'.
/// ```
String generateMigration(
  String resourceName,
  List<BeakFieldSpec> fields, {
  required String timestamp,
}) {
  final String table = tableNameOf(resourceName);
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:beak/migrations.dart';")
    ..writeln()
    ..writeln('/// Creates the $table table.')
    ..writeln(
      'final class Create${pluralOf(resourceName)}Table extends Migration {',
    )
    ..writeln('  /// Creates the migration.')
    ..writeln('  const Create${pluralOf(resourceName)}Table();')
    ..writeln()
    ..writeln('  @override')
    ..writeln("  String get name => '${timestamp}_create_${table}_table';")
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Future<void> upSchema(Schema schema) async {')
    ..writeln("    await schema.create('$table', (table) {")
    ..writeln('      table.idUuid();');
  for (final field in fields) {
    out.writeln('      table.${_blueprintCallOf(field)};');
  }
  out
    ..writeln('      table.timestamps();')
    ..writeln('    });')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Future<void> downSchema(Schema schema) async =>')
    ..writeln("      schema.drop('$table', ifExists: true);")
    ..writeln('}');
  return out.toString();
}

/// The create-table migration for [resourceName], derived from its model
/// rather than restated field by field.
///
/// `BeakBlueprint.defineColumns` reads the same `BeakModel` the API and the
/// panel read, so the table and the resource cannot drift: adding a column to
/// the schema class changes the DDL with no second edit. That is the argument
/// for `--from` over `--fields`.
///
/// [modelClass] is the generated model (`ProductModel`) and [importPath] the
/// library declaring the schema class, relative to `lib/migrations/`.
///
/// ```dart
/// final source = generateModelMigration(
///   'Product',
///   modelClass: 'ProductModel',
///   importPath: '../models/product.dart',
///   timestamp: '20260703_120000',
/// );
/// ```
String generateModelMigration(
  String resourceName, {
  required String modelClass,
  required String importPath,
  required String timestamp,
}) {
  final String table = tableNameOf(resourceName);
  return '''
import 'package:beak/migrations.dart';

import '$importPath';

/// Creates the $table table.
final class Create${pluralOf(resourceName)}Table extends Migration {
  /// Creates the migration.
  const Create${pluralOf(resourceName)}Table();

  @override
  String get name => '${timestamp}_create_${table}_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Derived from the model, so the table and the resource cannot drift.
    await schema.create('$table', (table) {
      BeakBlueprint.defineColumns(table, const $modelClass());
      BeakBlueprint.defineForeignKeys(table, const $modelClass());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('$table', ifExists: true);
}
''';
}

/// Returns the Dart source of the Beak columns class and `BeakModel` for
/// [resourceName] — the define-once definition both the server and the
/// Flutter panel consume.
///
/// The generated `abstract final class <Name>Columns` exposes a typed
/// `BeakColumn` constant per field in [fields] (plus a detail-only `id`) and
/// a `values` list; the accompanying `<Name>Model extends BeakModel` wires
/// up the [tableNameOf] table, uses the first field (or `id` when [fields]
/// is empty) as the display column, and carries those columns. The class
/// doc includes the `BeakResource` snippet to register it in a panel.
///
/// ```dart
/// final specs = BeakFieldSpec.parseList('name:string,price:decimal');
/// final source = generateBeakColumns('Product', specs);
/// // source declares `abstract final class ProductColumns` and
/// // `final class ProductModel extends BeakModel`.
/// ```
String generateBeakColumns(String resourceName, List<BeakFieldSpec> fields) {
  final String table = tableNameOf(resourceName);
  final String displayKey = fields.isEmpty ? 'id' : fields.first.name;
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:beak/beak.dart';")
    ..writeln()
    ..writeln('/// Typed column constants of the $table resource.')
    ..writeln('abstract final class ${resourceName}Columns {')
    ..writeln('  /// Primary key.')
    ..writeln('  static const id = BeakStringColumn(')
    ..writeln("    key: 'id',")
    ..writeln("    label: 'Id',")
    ..writeln('    visibleOn: {BeakContext.detail},')
    ..writeln('  );')
    ..writeln();
  for (final field in fields) {
    out
      ..writeln('  /// The `${field.name}` column.')
      ..writeln('  static const ${field.camelName} = ${_beakColumnOf(field)};')
      ..writeln();
  }
  out
    ..writeln('  /// All columns, in display order.')
    ..writeln('  static const List<BeakColumn> values = [')
    ..writeln('    id,')
    ..write([for (final field in fields) '    ${field.camelName},\n'].join())
    ..writeln('  ];')
    ..writeln('}')
    ..writeln()
    ..writeln('/// The $table resource.')
    ..writeln('///')
    ..writeln('/// Discovered under `lib/models/` — there is no registry to')
    ..writeln('/// edit and no resource to register. Set its icon and section')
    ..writeln('/// in `beak.yaml`:')
    ..writeln('///')
    ..writeln('/// ```yaml')
    ..writeln('/// resources:')
    ..writeln('///   $table:')
    ..writeln('///     icon: box')
    ..writeln('/// ```')
    ..writeln('final class ${resourceName}Model extends BeakModel {')
    ..writeln('  /// Creates the model.')
    ..writeln('  const ${resourceName}Model();')
    ..writeln()
    ..writeln('  @override')
    ..writeln("  String get table => '$table';")
    ..writeln()
    ..writeln('  @override')
    ..writeln("  String get displayColumnKey => '$displayKey';")
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  List<BeakColumn> get columns => ${resourceName}Columns.values;',
    )
    ..writeln('}');
  return out.toString();
}

String _dartTypeOf(BeakFieldKind kind) => switch (kind) {
  BeakFieldKind.string || BeakFieldKind.text => 'String',
  BeakFieldKind.integer => 'int',
  BeakFieldKind.decimal => 'double',
  BeakFieldKind.boolean => 'bool',
  BeakFieldKind.dateTime => 'DateTime',
};

String _fallbackOf(BeakFieldKind kind) => switch (kind) {
  BeakFieldKind.string || BeakFieldKind.text => "''",
  BeakFieldKind.integer => '0',
  BeakFieldKind.decimal => '0.0',
  BeakFieldKind.boolean => 'false',
  BeakFieldKind.dateTime => 'DateTime.fromMillisecondsSinceEpoch(0)',
};

String _wormFieldTypeOf(BeakFieldKind kind) => switch (kind) {
  BeakFieldKind.string || BeakFieldKind.text => 'StringField',
  BeakFieldKind.integer => 'ComparableField<int>',
  BeakFieldKind.decimal => 'ComparableField<double>',
  BeakFieldKind.boolean => 'Field<bool>',
  BeakFieldKind.dateTime => 'ComparableField<DateTime>',
};

String _blueprintCallOf(BeakFieldSpec field) => switch (field.kind) {
  BeakFieldKind.string => "string('${field.name}')",
  BeakFieldKind.text => "text('${field.name}')",
  BeakFieldKind.integer => "integer('${field.name}')",
  BeakFieldKind.decimal => "decimal('${field.name}')",
  BeakFieldKind.boolean => "boolean('${field.name}')",
  BeakFieldKind.dateTime => "dateTime('${field.name}').makeNullable()",
};

String _beakColumnOf(BeakFieldSpec field) => switch (field.kind) {
  BeakFieldKind.string =>
    "BeakStringColumn(key: '${field.name}', label: '${_labelOf(field)}', "
        'searchable: true, sortable: true)',
  BeakFieldKind.text =>
    "BeakTextColumn(key: '${field.name}', label: '${_labelOf(field)}')",
  BeakFieldKind.integer =>
    "BeakIntColumn(key: '${field.name}', label: '${_labelOf(field)}', "
        'sortable: true)',
  BeakFieldKind.decimal =>
    "BeakDecimalColumn(key: '${field.name}', label: '${_labelOf(field)}', "
        'sortable: true)',
  BeakFieldKind.boolean =>
    "BeakBoolColumn(key: '${field.name}', label: '${_labelOf(field)}', "
        'filterable: true)',
  BeakFieldKind.dateTime =>
    "BeakDateTimeColumn(key: '${field.name}', label: '${_labelOf(field)}', "
        'sortable: true)',
};

String _labelOf(BeakFieldSpec field) {
  final String spaced = field.name.replaceAll('_', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
