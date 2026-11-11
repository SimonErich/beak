part of 'serverpod_ir.dart';

void _addRelations(
  SpyProject project,
  DatabaseDefinition database,
  _Draft draft,
  Map<String, BeakSchemaIr> schemas,
  Map<String, String> byTable,
  DefinitionResource resource,
  Set<String> usedEnums,
  BeakIssueSink issues,
) {
  final fields = draft.fields;
  final relations = <BeakRelationIr>[];
  for (final name in draft.relationFields) {
    final field = fields[name]!;
    final rel = field.relation!;
    // A foreign key declared as `authorId` reads as the `author` relation.
    final relationName = name.endsWith('Id')
        ? name.substring(0, name.length - 2)
        : name;
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
          fieldName: relationName,
          key: rel.name ?? relationName,
          label: resource.fields[relationName]?.label ?? titleCaseOf(name),
          kind: BeakRelationKind.hasMany,
          relatedSchema: targetName!,
          foreignKey: fk,
          owned: resource.ownedRelations.contains(name),
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
            fieldName: relationName,
            key: rel.name ?? relationName,
            label: resource.fields[relationName]?.label ?? titleCaseOf(name),
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
        fieldName: relationName,
        key: rel.name ?? relationName,
        label: resource.fields[relationName]?.label ?? titleCaseOf(name),
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
      arguments: const {'semantic': 'BeakSemantic.uuid()', 'visibleOn': '{}'},
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
