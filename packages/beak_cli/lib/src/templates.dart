import 'field_spec.dart';

/// Generates the canonical worm model for [resourceName] — `tableName`
/// override, typed getters, `toRow`, `fromRow` hydration, the `static
/// query()` builder, and the `$` field-companion class — following every
/// convention in CLAUDE.md, no codegen required.
String generateWormModel(String resourceName, List<BeakFieldSpec> fields) {
  final String table = tableNameOf(resourceName);
  final String companion = '$resourceName\$';
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:worm/worm.dart';")
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

/// Generates the worm migration creating [resourceName]'s table.
String generateMigration(
  String resourceName,
  List<BeakFieldSpec> fields, {
  required String timestamp,
}) {
  final String table = tableNameOf(resourceName);
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:worm/worm.dart';")
    ..writeln()
    ..writeln('/// Creates the $table table.')
    ..writeln('final class Create${resourceName}sTable extends Migration {')
    ..writeln('  /// Creates the migration.')
    ..writeln('  const Create${resourceName}sTable();')
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

/// Generates the Beak columns class and `BeakModel` for [resourceName] —
/// the define-once definition both apps consume. Ends with the
/// `BeakResource` registration snippet as documentation.
String generateBeakColumns(String resourceName, List<BeakFieldSpec> fields) {
  final String table = tableNameOf(resourceName);
  final String displayKey = fields.isEmpty ? 'id' : fields.first.name;
  final StringBuffer out = StringBuffer()
    ..writeln("import 'package:beak_core/beak_core.dart';")
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
    ..writeln('/// Register it in the panel:')
    ..writeln('/// ```dart')
    ..writeln('/// BeakResource(')
    ..writeln('///   model: ${resourceName}Model(),')
    ..writeln('///   icon: BeakIconToken(OiIcons.box),')
    ..writeln('/// )')
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
