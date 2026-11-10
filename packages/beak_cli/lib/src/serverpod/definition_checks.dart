import '../introspect/beak_schema_introspection.dart' show isSecretColumnName;
import 'database_definition.dart';
import 'definition_model.dart';
import 'generate_issue.dart';
import 'spy_model.dart';

/// The relation a Serverpod relation field stands for (`authorId` reads as
/// `author`).
String relationNameOf(SpyField field) => field.name.endsWith('Id')
    ? field.name.substring(0, field.name.length - 2)
    : field.name;

/// The foreign key a Serverpod relation field stores.
String foreignKeyOf(SpyField field) {
  if (field.relation?.field case final String key) return key;
  if (field.name.endsWith('Id') ||
      field.baseType == 'UuidValue' ||
      field.baseType == 'int') {
    return field.columnName;
  }
  return '${field.name}Id';
}

/// The type a definition class declares for a Serverpod field.
String declaredTypeOf(SpyField field, SpyProject project) {
  final type = field.baseType;
  if (project.enums.containsKey(type)) return type;
  return switch (type) {
    'String' || 'Uri' || 'UuidValue' => 'String',
    'int' || 'BigInt' || 'Duration' => 'int',
    'double' => 'double',
    'bool' => 'bool',
    'DateTime' => 'DateTime',
    _ => 'BeakJson',
  };
}

/// Reports every declared field Serverpod does not have as declared.
void checkDeclaredFields(
  DefinitionClass definition,
  Map<String, SpyField> spyFields,
  DbTable? table,
  SpyProject project,
  Set<String> names,
  BeakIssueSink issues,
) {
  final owner = definition.name;
  void report(String message) => issues.add(definition.path, message);
  final foreignKeys = {
    for (final field in spyFields.values)
      if (field.relation != null &&
          !field.isCollection &&
          (table?.columns.containsKey(foreignKeyOf(field)) ?? false))
        foreignKeyOf(field): field,
  };
  for (final field in definition.fields) {
    final what = '$owner.${field.name}';
    final relation = field.relation;
    if (relation != null) {
      final spy = spyFields[field.name] ?? spyFields['${field.name}Id'];
      if (spy == null || spy.relation == null) {
        report('$what is not a relation of the Serverpod model $owner.');
        continue;
      }
      final many = relation.kind == DefinitionRelationKind.hasMany;
      if (many != spy.isCollection) {
        report(
          many
              ? '$what is a single relation in Serverpod; use @BelongsTo or '
                    '@HasOne.'
              : '$what is a list in Serverpod; declare it '
                    '`@HasMany() late final List<${spy.elementType}> '
                    '${field.name};`.',
        );
        continue;
      }
      final target = many
          ? spy.elementType
          : spy.relation?.parent == null
          ? spy.baseType
          : project.classOfTable(spy.relation!.parent!)?.name;
      if (target != relation.target) {
        report('$what points at $target in Serverpod, not ${relation.target}.');
      } else if (!names.contains(target)) {
        report(
          '$what points at $target, which no definition class exposes. '
          'Add a class for it, or leave the relation out.',
        );
      }
      if (!many &&
          spy.relation?.parent == null &&
          spy.nullable != field.nullable) {
        report(
          '$what is ${spy.nullable ? 'optional' : 'required'} in Serverpod; '
          'declare it ${spy.nullable ? 'with' : 'without'} `?`.',
        );
      }
      continue;
    }
    final spy = spyFields[field.name];
    if (spy == null) {
      if (field.name == 'id') {
        final stored = table?.columns[field.name]?.dartType ?? 'String';
        _checkType(
          what,
          field,
          stored.startsWith('int') ? 'int' : 'String',
          report,
        );
        continue;
      }
      if (foreignKeys[field.name] case final SpyField foreign) {
        final stored = table?.columns[field.name]?.dartType ?? 'String';
        _checkType(
          what,
          field,
          stored.startsWith('int') ? 'int' : 'String',
          report,
        );
        if (foreign.nullable != field.nullable) {
          report(
            '$what is ${foreign.nullable ? 'nullable' : 'not nullable'} in '
            'Serverpod (`${foreign.type}`); declare it '
            '${foreign.nullable ? 'with' : 'without'} `?`.',
          );
        }
        continue;
      }
      report('$what is not a field of the Serverpod model $owner.');
      continue;
    }
    if (spy.isCollection && spy.relation != null) {
      report(
        '$what is a relation in Serverpod; declare it '
        '`@HasMany() late final List<${spy.elementType}> ${field.name};`.',
      );
      continue;
    }
    if (!spy.persist || spy.isServerOnly) {
      report('$what is not stored or is server only in Serverpod.');
      continue;
    }
    if (isSecretColumnName(spy.name) || isSecretColumnName(spy.columnName)) {
      report('$what looks like a secret; Beak never exposes it.');
      continue;
    }
    if (field.name == 'id') continue;
    _checkType(what, field, declaredTypeOf(spy, project), report);
    if (spy.nullable != field.nullable) {
      report(
        '$what is ${spy.nullable ? 'nullable' : 'not nullable'} in Serverpod '
        '(`${spy.type}`); declare it ${spy.nullable ? 'with' : 'without'} `?`.',
      );
    }
  }
}

void _checkType(
  String what,
  DefinitionField field,
  String expected,
  void Function(String) report,
) {
  if (field.typeName == expected) return;
  report(
    '$what is declared `${field.typeName}`, but the Serverpod field reads as '
    '`$expected` in the admin.',
  );
}

/// Reports a required Serverpod field a stock create would leave empty.
void checkStockCreate(
  DefinitionClass definition,
  Map<String, SpyField> spyFields,
  List<String> writeFields,
  BeakIssueSink issues,
) {
  final filled = {
    ...writeFields,
    for (final field in definition.fields)
      if (field.hidden && field.hiddenDefault != null) field.name,
  };
  for (final field in spyFields.values) {
    if (field.name == 'id' || field.nullable || field.hasDefault) continue;
    if (!field.persist || field.isCollection) continue;
    if (const {'createdAt', 'updatedAt', 'isDeleted'}.contains(field.name)) {
      continue;
    }
    final key = field.relation == null ? field.name : foreignKeyOf(field);
    if (filled.contains(key)) continue;
    issues.add(
      definition.path,
      '${definition.name} creates records the stock way, but the required '
      'Serverpod field "${field.name}" gets no value. Declare it writable, '
      'give it @Hidden(defaultValue: ...), or make create custom.',
    );
  }
}
