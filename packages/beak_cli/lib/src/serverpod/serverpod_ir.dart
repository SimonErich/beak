import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart' show titleCaseOf;
import '../introspect/beak_schema_introspection.dart' show isSecretColumnName;
import 'database_definition.dart';
import 'generate_issue.dart';
import 'generate_settings.dart';
import 'inventory_model.dart';
import 'spy_model.dart';

/// Everything `beak generate` derives from the Serverpod project.
final class ServerpodIr {
  /// Creates a generated project.
  const ServerpodIr({
    required this.models,
    required this.inputs,
    required this.enums,
    required this.writes,
  });

  /// The admitted models, in inventory order.
  final List<BeakGeneratedModel> models;

  /// The non-persisted command inputs.
  final List<BeakGeneratedInput> inputs;

  /// The Serverpod enums the models use.
  final List<BeakGeneratedEnum> enums;

  /// The write bindings, emitted as an enum.
  final List<String> writes;
}

/// Reads the Serverpod models, the newest migration and the inventory into the
/// IR the emitter writes.
ServerpodIr buildServerpodIr({
  required SpyProject project,
  required DatabaseDefinition database,
  required Inventory inventory,
  required BeakGenerateSettings settings,
}) {
  final issues = BeakIssueSink();
  _validateRoleNames(project, settings, issues);
  final schemas = <String, BeakSchemaIr>{};
  final drafts = <String, _Draft>{};
  for (final resource in inventory.resources.values) {
    final spy = project.classes[resource.name];
    final table = spy?.table;
    if (spy == null || table == null) {
      issues.add(resource.path, '${resource.name} is not a persisted model.');
      continue;
    }
    if (spy.serverOnly) {
      issues.add(resource.path, '${resource.name} is serverOnly.');
      continue;
    }
    if (database.tables[table] == null) {
      issues.add(
        resource.path,
        '${resource.name} maps to "$table", which the newest migration does '
        'not contain. Run `serverpod create-migration` first.',
      );
      continue;
    }
    drafts[resource.name] = _draftFor(
      project,
      database.tables[table]!,
      spy,
      resource,
      settings,
      issues,
    );
  }
  for (final entry in drafts.entries) {
    schemas[entry.key] = entry.value.schema;
  }
  final byTable = {
    for (final entry in drafts.entries)
      project.classes[entry.key]!.table!: entry.key,
  };
  final usedEnums = <String>{};
  final models = <BeakGeneratedModel>[];
  for (final entry in drafts.entries) {
    final resource = inventory.resources[entry.key]!;
    final draft = entry.value;
    _addRelations(
      project,
      database,
      draft,
      schemas,
      byTable,
      resource,
      usedEnums,
      issues,
    );
    final admission = _admissionFor(draft, resource, settings, issues);
    final permissions = _permissionsFor(resource, settings);
    final capabilities = {
      for (final operation in resource.operations) operation,
    };
    models.add(
      BeakGeneratedModel(
        schema: draft.schema,
        capabilities: capabilities,
        permissions: permissions,
        admission: admission,
      ),
    );
  }
  _validateInventory(project, database, inventory, drafts, issues);
  final inputs = _inputs(project, inventory, schemas, usedEnums, issues);
  issues.throwIfAny();
  final enums = <String, BeakGeneratedEnum>{
    for (final model in models)
      for (final column in model.schema.columns)
        if (column.enumTypeName case final String name)
          if (project.enums[name] case final SpyEnum type) name: _enumOf(type),
    for (final name in usedEnums)
      if (project.enums[name] case final SpyEnum type) name: _enumOf(type),
  };
  return ServerpodIr(
    models: models,
    inputs: inputs,
    enums: enums.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    writes: settings.writes,
  );
}

void _validateRoleNames(
  SpyProject project,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final roles = settings.roles;
  if (roles == null || settings.areas.isEmpty) return;
  final roleEnum = project.enums[roles];
  if (roleEnum == null) {
    issues.add(
      'beak.yaml',
      'generate.roles names "$roles", which is not an enum of the server.',
    );
    return;
  }
  final names = {for (final value in roleEnum.values) value.name};
  for (final area in settings.areas.entries) {
    for (final role in [...area.value.read, ...area.value.write]) {
      if (!names.contains(role)) {
        issues.add(
          'beak.yaml',
          'generate.areas.${area.key} names "$role", which $roles does not '
              'declare.',
        );
      }
    }
  }
}

final class _Draft {
  _Draft(this.schema, this.spy, this.db, this.resource, this.fields);
  final BeakSchemaIr schema;
  final SpyClass spy;
  final DbTable db;
  final InventoryResource resource;
  final Map<String, SpyField> fields;
  final List<String> relationFields = [];
  final List<String> hidden = [];
}

_Draft _draftFor(
  SpyProject project,
  DbTable db,
  SpyClass spy,
  InventoryResource resource,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final fields = {for (final field in project.fieldsOf(spy)) field.name: field};
  final columns = <BeakColumnIr>[];
  final relationFields = <String>[];
  final hidden = <String>[];
  final consumed = <String>{};
  final seen = <String>{};
  for (final field in fields.values) {
    final physical = field.columnName;
    if (resource.exclude.contains(field.name)) continue;
    if (resource.hidden.contains(field.name)) hidden.add(field.name);
    if (!field.persist) continue;
    if (field.isServerOnly) continue;
    if (isSecretColumnName(field.name) || isSecretColumnName(physical)) {
      continue;
    }
    final isRelation = field.relation != null;
    final scalarRelation = resource.scalarRelations.contains(field.name);
    if (isRelation && scalarRelation) {
      final fk = _fkOf(field);
      if (db.columns.containsKey(fk) && seen.add(fk)) {
        columns.add(
          _fkColumn(
            db.columns[fk]!,
            fk,
            resource,
            settings,
            hidden: false,
            formSlot: true,
          ),
        );
      }
      continue;
    }
    if (isRelation) {
      relationFields.add(field.name);
      final fk = field.relation!.field ?? _fkOf(field);
      if (db.columns.containsKey(fk) && seen.add(fk)) {
        columns.add(
          _fkColumn(
            db.columns[fk]!,
            fk,
            resource,
            settings,
            hidden: true,
            omitFromValues: false,
            formSlot: true,
          ),
        );
        consumed.add(fk);
      }
      continue;
    }
    if (field.isCollection) {
      // A collection of another model is a relationship; only value lists
      // become a JSON column.
      if (project.classes.containsKey(field.elementType)) continue;
      columns.add(_column(project, field, db, resource, settings, issues));
      seen.add(field.name);
      continue;
    }
    columns.add(_column(project, field, db, resource, settings, issues));
    seen.add(field.name);
  }
  for (final field in relationFields) {
    final rel = fields[field]!.relation!;
    final fk = rel.field ?? _fkOf(fields[field]!);
    if (db.columns.containsKey(fk) && seen.add(fk)) {
      columns.add(
        _fkColumn(db.columns[fk]!, fk, resource, settings, hidden: true),
      );
      consumed.add(fk);
    }
  }
  if (!seen.contains('id')) {
    if (db.columns['id'] case final DbColumn id) {
      columns.insert(
        0,
        _fkColumn(id, 'id', resource, settings, hidden: false),
      );
    }
  }
  final display = resource.display ?? _displayOf(columns);
  final softDeletes =
      columns.any((column) => column.fieldName == 'deletedAt') &&
      columns.any((column) => column.fieldName == 'isDeleted');
  final timestamps =
      columns.any((column) => column.fieldName == 'createdAt') &&
      columns.any((column) => column.fieldName == 'updatedAt');
  final schema = BeakSchemaIr(
    className: spy.name,
    table: spy.table!,
    libraryPath: 'src/models/${_snake(spy.name)}.dart',
    columns: columns,
    relations: [],
    displayColumnKey: _columnKeyOf(columns, display),
    softDeletes: softDeletes,
    timestamps: timestamps,
    managesSchema: false,
    hasBehavior: true,
    hasPermissions: true,
    hasCapabilities: true,
    createdAtColumnKey: _columnKeyOf(columns, 'createdAt'),
    updatedAtColumnKey: _columnKeyOf(columns, 'updatedAt'),
    deletedAtColumnKey: _columnKeyOf(columns, 'deletedAt'),
    isDeletedColumnKey: softDeletes ? _columnKeyOf(columns, 'isDeleted') : null,
  );
  return _Draft(schema, spy, db, resource, fields)
    ..relationFields.addAll(relationFields)
    ..hidden.addAll(hidden);
}

BeakColumnIr _column(
  SpyProject project,
  SpyField field,
  DbTable db,
  InventoryResource resource,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final override = resource.fields[field.name];
  final name = override?.name ?? field.name;
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
  if (override?.min case final num min) args['rules'] = 'BeakMin($min)';
  if (override?.max case final num max) {
    final existing = args.remove('rules');
    args['rules'] = existing == null
        ? 'BeakMax($max)'
        : '[$existing, BeakMax($max)]';
  }
  return BeakColumnIr(
    fieldName: name,
    columnKey: field.columnName,
    label: override?.label ?? titleCaseOf(name),
    kind: type.kind,
    isRequired: !field.nullable,
    enumTypeName: type.enumTypeName,
    arguments: args,
    docComment: 'Serverpod `${field.name}` (`${field.baseType}`).',
  );
}

BeakColumnIr _fkColumn(
  DbColumn column,
  String fieldName,
  InventoryResource resource,
  BeakGenerateSettings settings, {
  required bool hidden,
  bool omitFromValues = false,
  bool formSlot = false,
}) {
  final uuid = column.dartType.startsWith('UuidValue');
  final kind = uuid ? BeakColumnKind.string : _kindOfDb(column.dartType);
  final label = resource.fields[fieldName]?.label ?? titleCaseOf(fieldName);
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
    },
    docComment: 'The stored foreign key `${column.name}`.',
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

BeakColumnKind _kindOfDb(String dartType) {
  final type = dartType.replaceAll('?', '');
  return switch (type) {
    'int' || 'Duration' || 'BigInt' => BeakColumnKind.integer,
    'double' => BeakColumnKind.decimal,
    'bool' => BeakColumnKind.boolean,
    'DateTime' => BeakColumnKind.dateTime,
    'UuidValue' => BeakColumnKind.string,
    _ => BeakColumnKind.string,
  };
}

String _fkOf(SpyField field) {
  if (field.relation?.field case final String fieldKey) return fieldKey;
  if (field.name.endsWith('Id') ||
      field.baseType == 'UuidValue' ||
      field.baseType == 'int') {
    return field.columnName;
  }
  return '${field.name}Id';
}

bool _isForeignKey(String name) => name.endsWith('Id');

String _displayOf(List<BeakColumnIr> columns) {
  for (final column in columns) {
    if (column.kind == BeakColumnKind.string &&
        column.fieldName != 'id' &&
        !_isForeignKey(column.fieldName)) {
      return column.fieldName;
    }
  }
  return columns.isEmpty ? 'id' : columns.first.fieldName;
}

String _columnKeyOf(List<BeakColumnIr> columns, String field) {
  for (final column in columns) {
    if (column.fieldName == field || column.columnKey == field) {
      return column.columnKey;
    }
  }
  return field;
}

String? _defaultSource(
  SpyField field,
  InventoryResource resource,
  ({BeakColumnKind kind, String? enumTypeName}) type,
) {
  final reviewed = resource.defaults[field.name];
  if (reviewed != null) return _literal(reviewed);
  final raw = field.defaultValue;
  if (raw == null || raw == 'now' || raw.isEmpty) return null;
  if (type.enumTypeName != null) return '${type.enumTypeName}.$raw';
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw) ||
      raw == 'true' ||
      raw == 'false' ||
      raw == 'null' ||
      raw.startsWith("'") ||
      raw.startsWith('"')) {
    return raw;
  }
  return "'${raw.replaceAll("'", r"\'")}'";
}

String _literal(Object? value) => switch (value) {
  final String text =>
    "'${text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'",
  final bool boolean => '$boolean',
  final num number => '$number',
  null => 'null',
  _ => throw BeakGenerateException.single(
    'beak.yaml',
    'Unsupported default value "$value".',
  ),
};

bool _isMoney(String name, BeakMoneyConvention? money) {
  if (money == null) return false;
  return money.fields.any((pattern) => _matches(pattern, name));
}

bool _isDateOnly(String name, BeakGenerateConventions conventions) =>
    conventions.dateOnly.any((pattern) => _matches(pattern, name));

bool _detailOnly(String name, BeakGenerateConventions conventions, bool id) =>
    id ||
    const {'createdAt', 'updatedAt', 'deletedAt', 'isDeleted'}.contains(name) ||
    conventions.detailOnly.any((pattern) => _matches(pattern, name));

bool _matches(String pattern, String name) {
  if (!pattern.contains('*')) return pattern == name;
  final prefix = pattern.substring(0, pattern.indexOf('*'));
  final suffix = pattern.substring(pattern.indexOf('*') + 1);
  return name.startsWith(prefix) && name.endsWith(suffix);
}

void _addRelations(
  SpyProject project,
  DatabaseDefinition database,
  _Draft draft,
  Map<String, BeakSchemaIr> schemas,
  Map<String, String> byTable,
  InventoryResource resource,
  Set<String> usedEnums,
  BeakIssueSink issues,
) {
  final fields = draft.fields;
  final relations = <BeakRelationIr>[];
  for (final name in draft.relationFields) {
    final field = fields[name]!;
    final rel = field.relation!;
    if (field.isCollection) {
      final targetName = field.elementType;
      final target = targetName == null ? null : schemas[targetName];
      if (target == null) continue;
      final fk = _inverseKey(
        project,
        database,
        draft,
        target,
        field,
        byTable,
        issues,
      );
      if (fk == null) continue;
      if (fk.startsWith('_')) _ensureShadowColumn(target, draft, fk);
      relations.add(
        BeakRelationIr(
          fieldName: name,
          key: rel.name ?? name,
          label: titleCaseOf(name),
          kind: BeakRelationKind.hasMany,
          relatedSchema: targetName!,
          foreignKey: fk,
        ),
      );
      continue;
    }
    final targetTable = rel.parent;
    final targetName = targetTable == null
        ? field.baseType
        : byTable[targetTable];
    final target = targetName == null ? null : schemas[targetName];
    if (target == null) continue;
    final fk = rel.field ?? _fkOf(field);
    final own = database.tables[draft.spy.table];
    final hasOwnFk = own?.columns.containsKey(fk) ?? false;
    if (!hasOwnFk && rel.field == null) {
      final counterpart = _counterpart(project, draft, target, field);
      if (counterpart != null) {
        relations.add(
          BeakRelationIr(
            fieldName: name,
            key: rel.name ?? name,
            label: titleCaseOf(name),
            kind: BeakRelationKind.hasOne,
            relatedSchema: targetName!,
            foreignKey: counterpart,
            isRequired: !field.nullable,
          ),
        );
        continue;
      }
      issues.add(
        resource.path,
        '${draft.spy.name}.$name has no foreign key "$fk" in the newest '
        'migration and no named counterpart. Name both Serverpod relation '
        'sides with relation(name: ...).',
      );
      continue;
    }
    relations.add(
      BeakRelationIr(
        fieldName: name,
        key: rel.name ?? name,
        label: titleCaseOf(name),
        kind: BeakRelationKind.belongsTo,
        relatedSchema: targetName!,
        foreignKey: fk,
        isRequired: !field.nullable,
        arguments: {
          if (rel.onDelete case final String action)
            'onDelete': 'BeakOnDelete.${_onDeleteOf(action)}',
        },
      ),
    );
  }
  draft.schema.relations.addAll(relations);
}

String? _inverseKey(
  SpyProject project,
  DatabaseDefinition database,
  _Draft draft,
  BeakSchemaIr target,
  SpyField field,
  Map<String, String> byTable,
  BeakIssueSink issues,
) {
  final rel = field.relation!;
  if (rel.name != null) {
    final counterpart = _counterpart(project, draft, target, field);
    if (counterpart != null) return counterpart;
  }
  final targetTable = project.classes[target.className]!.table!;
  final candidates = <String>{
    for (final other in project.fieldsOf(project.classes[target.className]!))
      if (other.relation?.parent == draft.schema.table)
        other.relation!.field ?? _fkOf(other),
    if (database.tables[targetTable] case final DbTable table)
      for (final key in table.foreignKeys)
        if (key.referenceTable == draft.schema.table) ...key.columns,
  };
  if (candidates.length == 1) return candidates.single;
  if (candidates.length > 1) {
    final generated =
        '_${_camel(draft.schema.table)}${_upperFirst(field.name)}${_upperFirst(_camel(draft.schema.table))}Id';
    if (candidates.contains(generated)) return generated;
    issues.add(
      draft.resource.path,
      '${draft.spy.name}.${field.name} has several possible foreign keys '
      '(${candidates.join(', ')}). Name both Serverpod relation sides.',
    );
    return null;
  }
  // A one-sided has-many has no foreign key until Serverpod invents one.
  final own = byTable[targetTable];
  final generated =
      '_${_camel(draft.schema.table)}${_upperFirst(field.name)}${_upperFirst(_camel(draft.schema.table))}Id';
  if (own != null && project.classes.containsKey(own)) return generated;
  issues.add(
    draft.resource.path,
    'Cannot resolve ${draft.spy.name}.${field.name}: the target table holds '
    'no foreign key back to "${draft.spy.table}".',
  );
  return null;
}

void _ensureShadowColumn(BeakSchemaIr child, _Draft owner, String foreignKey) {
  final field =
      '${owner.spy.name[0].toLowerCase()}${owner.spy.name.substring(1)}Id';
  if (child.columns.any(
    (column) => column.fieldName == field || column.columnKey == foreignKey,
  )) {
    return;
  }
  child.columns.add(
    BeakColumnIr(
      fieldName: field,
      columnKey: foreignKey,
      label: titleCaseOf(field),
      kind: BeakColumnKind.string,
      isRequired: false,
      arguments: const {
        'semantic': 'BeakSemantic.uuid()',
        'visibleOn': '{}',
      },
      docComment: 'The stored foreign key `$foreignKey`.',
    ),
  );
}

String? _counterpart(
  SpyProject project,
  _Draft draft,
  BeakSchemaIr target,
  SpyField field,
) {
  final name = field.relation!.name;
  if (name == null) return null;
  for (final candidate in project.fieldsOf(
    project.classes[target.className]!,
  )) {
    if (candidate.relation?.name != name) continue;
    if (candidate.relation?.parent == draft.spy.table) {
      return candidate.relation!.field ?? _fkOf(candidate);
    }
    if (candidate.baseType == draft.spy.name) {
      if (candidate.type.startsWith('List<')) continue;
      if (candidate.name == field.name && target.className == draft.spy.name) {
        continue;
      }
      return candidate.relation!.field ?? _fkOf(candidate);
    }
  }
  return null;
}

BeakAdmissionIr _admissionFor(
  _Draft draft,
  InventoryResource resource,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final columns = {
    for (final column in draft.schema.columns) column.fieldName,
    for (final column in draft.schema.columns) column.columnKey,
  };
  final writable = <String>[];
  for (final field in resource.writeFields ?? const <String>[]) {
    if (!columns.contains(field)) {
      issues.add(
        resource.path,
        '${resource.name}.writeFields names "$field", which is not a generated '
        'column.',
      );
      continue;
    }
    if (const {
      'id',
      'createdAt',
      'updatedAt',
      'deletedAt',
      'isDeleted',
    }.contains(field)) {
      issues.add(
        resource.path,
        '${resource.name}.writeFields names the '
        'server-owned "$field".',
      );
      continue;
    }
    for (final hidden in draft.hidden) {
      if (hidden == field) {
        issues.add(
          resource.path,
          '${resource.name}.writeFields names the '
          'hidden "$field".',
        );
      }
    }
    writable.add(field);
  }
  final hidden = [
    for (final field in draft.hidden)
      if (columns.contains(field)) field,
  ];
  final translation = _translationOf(draft, resource);
  final restoreKey =
      resource.restoreKey ??
      (translation == null ? null : [translation.owner, translation.locale]);
  return BeakAdmissionIr(
    writable: writable,
    hidden: hidden,
    restoreKey: restoreKey ?? const [],
    writeValue: resource.write == null
        ? null
        : '${settings.prefix ?? 'Generated'}Write.${resource.write}',
    reason: resource.reason,
    translationOwner: translation?.owner,
    translationLocale: translation?.locale,
  );
}

({String owner, String locale})? _translationOf(
  _Draft draft,
  InventoryResource resource,
) {
  if (resource.write != 'translation') return null;
  final locale = draft.schema.columns
      .where((column) => column.columnKey.toLowerCase() == 'locale')
      .map((column) => column.fieldName)
      .firstOrNull;
  if (locale == null) return null;
  for (final index in draft.db.indexes) {
    if (!index.isUnique) continue;
    final localeKey = index.columns
        .where((column) => column.toLowerCase() == 'locale')
        .firstOrNull;
    if (localeKey == null) continue;
    final ownerKey = index.columns
        .where((column) => column != localeKey)
        .firstOrNull;
    if (ownerKey == null) continue;
    final ownerField = draft.schema.columns
        .where((column) => column.columnKey == ownerKey)
        .map((column) => column.fieldName)
        .firstOrNull;
    if (ownerField != null) return (owner: ownerField, locale: locale);
  }
  return null;
}

BeakPermissionsIr _permissionsFor(
  InventoryResource resource,
  BeakGenerateSettings settings,
) {
  final area = resource.area == null ? null : settings.areas[resource.area];
  final read = resource.access.operations['read'] ?? area?.read ?? const [];
  final write = resource.access.operations['write'] ?? area?.write ?? const [];
  List<String>? override(String operation) =>
      resource.access.operations[operation];
  return BeakPermissionsIr(
    read: read,
    write: _writable(resource) ? write : const [],
    create: override('create'),
    update: override('update'),
    delete: override('delete'),
  );
}

bool _writable(InventoryResource resource) =>
    resource.writes && resource.write != null;

List<BeakGeneratedInput> _inputs(
  SpyProject project,
  Inventory inventory,
  Map<String, BeakSchemaIr> schemas,
  Set<String> usedEnums,
  BeakIssueSink issues,
) {
  final inputs = <BeakGeneratedInput>[];
  for (final input in inventory.inputs.values) {
    final columns = <BeakColumnIr>[];
    final relations = <BeakRelationIr>[];
    for (final entry in input.fields.entries) {
      final name = entry.key;
      final field = entry.value;
      final belongsTo = field.belongsTo;
      if (belongsTo != null) {
        final target = schemas[belongsTo];
        if (target == null) {
          issues.add(
            input.path,
            '${input.name}.$name belongs to "$belongsTo", which is not '
            'admitted.',
          );
          continue;
        }
        final fk = field.foreignKey ?? '${name}Id';
        final idColumn = target.columns
            .where((column) => column.fieldName == 'id')
            .firstOrNull;
        columns.add(
          BeakColumnIr(
            fieldName: fk,
            columnKey: fk,
            label: titleCaseOf(fk),
            kind: idColumn?.kind ?? BeakColumnKind.string,
            isRequired: field.required,
            arguments: {
              if (idColumn?.arguments['semantic'] case final String semantic)
                'semantic': semantic,
            },
          ),
        );
        relations.add(
          BeakRelationIr(
            fieldName: name,
            key: name,
            label: field.label ?? titleCaseOf(name),
            kind: BeakRelationKind.belongsTo,
            relatedSchema: belongsTo,
            foreignKey: fk,
            isRequired: field.required,
          ),
        );
        continue;
      }
      final type = field.type ?? 'String';
      final kind = switch (type) {
        'int' => BeakColumnKind.integer,
        'double' => BeakColumnKind.decimal,
        'bool' => BeakColumnKind.boolean,
        'DateTime' => BeakColumnKind.dateTime,
        _ => BeakColumnKind.string,
      };
      columns.add(
        BeakColumnIr(
          fieldName: name,
          columnKey: name,
          label: field.label ?? titleCaseOf(name),
          kind: kind,
          isRequired: field.required,
        ),
      );
    }
    final schema = BeakSchemaIr(
      className: input.name,
      table: input.table ?? 'input_${_snake(input.name)}',
      libraryPath: 'src/models/${_snake(input.name)}.dart',
      columns: columns,
      relations: relations,
      displayColumnKey: columns.isEmpty ? 'id' : columns.first.fieldName,
      softDeletes: false,
      timestamps: false,
      managesSchema: false,
      hasBehavior: true,
      hasPermissions: true,
      hasCapabilities: true,
    );
    inputs.add(BeakGeneratedInput(schema));
  }
  return inputs;
}

void _validateInventory(
  SpyProject project,
  DatabaseDefinition database,
  Inventory inventory,
  Map<String, _Draft> drafts,
  BeakIssueSink issues,
) {
  final tables = <String, String>{};
  for (final draft in drafts.values) {
    final table = draft.spy.table!;
    if (tables.containsKey(table)) {
      issues.add(
        draft.resource.path,
        '${draft.spy.name} and ${tables[table]} both map to "$table".',
      );
    }
    tables[table] = draft.spy.name;
    for (final column in draft.schema.columns) {
      if (!draft.db.columns.containsKey(column.columnKey)) {
        issues.add(
          draft.resource.path,
          '${draft.spy.name}.${column.fieldName} maps to '
          '"${column.columnKey}", which the newest migration lacks.',
        );
      }
    }
  }
}

BeakGeneratedEnum _enumOf(SpyEnum type) => BeakGeneratedEnum(
  name: type.name,
  properties: {
    for (final entry in type.properties.entries) entry.key: entry.value,
  },
  values: [
    for (final value in type.values)
      BeakGeneratedEnumValue(value.name, value.properties),
  ],
);

String _onDeleteOf(String action) => switch (action) {
  'Cascade' => 'cascade',
  'SetNull' => 'setNull',
  'SetDefault' => 'setDefault',
  _ => 'restrict',
};

String _snake(String name) => name
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? ''
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join();
}

String _upperFirst(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
