part of 'serverpod_ir.dart';

BeakColumnIr _column(
  SpyProject project,
  SpyField field,
  DbTable db,
  DefinitionResource resource,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final override = resource.fields[field.name];
  final name = field.name;
  final dbColumn = db.columns[field.columnName];
  if (dbColumn == null) {
    issues.add(
      resource.path,
      '${resource.name}.${field.name} is exposed but "${field.columnName}" '
      'is not in the newest migration.',
    );
  }
  final type = _kindOf(project, field, dbColumn);
  final args = <String, String>{};
  if (dbColumn != null && dbColumn.dartType.startsWith('UuidValue')) {
    args['semantic'] = 'BeakSemantic.uuid()';
  }
  if (_isMoney(field.name, settings.conventions.money)) {
    final money = settings.conventions.money!;
    args['semantic'] =
        "BeakSemantic.money(currency: '${money.currency}', scale: ${money.scale})";
  }
  if (_isDateOnly(field.name, settings.conventions)) {
    args['format'] = 'BeakDateFormat.dateOnly';
  }
  if (type.kind != BeakColumnKind.json) args['sortable'] = 'true';
  if (type.kind == BeakColumnKind.string && !_isForeignKey(field.name)) {
    args['searchable'] = 'true';
  }
  if (type.kind == BeakColumnKind.enumeration ||
      type.kind == BeakColumnKind.boolean) {
    args['filterable'] = 'true';
  }
  if (_detailOnly(field.name, settings.conventions, field.name == 'id')) {
    args['visibleOn'] = '{BeakContext.detail}';
  }
  final defaultSource = _defaultSource(field, resource, type);
  if (defaultSource != null) args['defaultValue'] = defaultSource;
  args.addAll(override?.arguments ?? const {});
  return BeakColumnIr(
    fieldName: name,
    columnKey: field.columnName,
    label: override?.label ?? titleCaseOf(name),
    kind: type.kind,
    isRequired: !field.nullable,
    enumTypeName: type.enumTypeName,
    declaredValueType: type.kind == BeakColumnKind.json ? 'BeakJson' : null,
    arguments: args,
    docComment:
        override?.doc ?? 'Serverpod `${field.name}` (`${field.baseType}`).',
  );
}

BeakColumnIr _fkColumn(
  DbColumn column,
  String fieldName,
  DefinitionResource resource,
  BeakGenerateSettings settings, {
  required bool hidden,
  bool omitFromValues = false,
  bool formSlot = false,
}) {
  final uuid = column.dartType.startsWith('UuidValue');
  final kind = uuid ? BeakColumnKind.string : _kindOfDb(column.dartType);
  final override = resource.fields[fieldName];
  final label = override?.label ?? titleCaseOf(fieldName);
  return BeakColumnIr(
    fieldName: fieldName,
    columnKey: column.name,
    label: label,
    kind: kind,
    isRequired: false,
    arguments: {
      if (uuid) 'semantic': 'BeakSemantic.uuid()',
      'visibleOn': formSlot
          ? '{BeakContext.form, BeakContext.detail}'
          : hidden
          ? '{}'
          : '{BeakContext.detail}',
      'filterable': 'true',
      ...?override?.arguments,
    },
    docComment: override?.doc ?? 'The stored foreign key `${column.name}`.',
    omitFromValues: omitFromValues,
  );
}

({BeakColumnKind kind, String? enumTypeName}) _kindOf(
  SpyProject project,
  SpyField field,
  DbColumn? dbColumn,
) {
  final type = field.baseType;
  if (type.startsWith('List<') || type.startsWith('Set<')) {
    return (kind: BeakColumnKind.json, enumTypeName: null);
  }
  if (project.enums.containsKey(type)) {
    return (kind: BeakColumnKind.enumeration, enumTypeName: type);
  }
  if (type == 'String' || type == 'Uri') {
    return (kind: BeakColumnKind.string, enumTypeName: null);
  }
  if (type == 'bool') return (kind: BeakColumnKind.boolean, enumTypeName: null);
  if (type == 'int' || type == 'Duration' || type == 'BigInt') {
    return (kind: BeakColumnKind.integer, enumTypeName: null);
  }
  if (type == 'double') {
    return (kind: BeakColumnKind.decimal, enumTypeName: null);
  }
  if (type == 'DateTime') {
    return (kind: BeakColumnKind.dateTime, enumTypeName: null);
  }
  if (type == 'UuidValue') {
    return (kind: BeakColumnKind.string, enumTypeName: null);
  }
  if (dbColumn?.dartType.startsWith('UuidValue') ?? false) {
    return (kind: BeakColumnKind.string, enumTypeName: null);
  }
  // An enum, a list, a module type or an unknown class: the JSON text column
  // is the only representation that never invents a type.
  return (kind: BeakColumnKind.json, enumTypeName: null);
}
