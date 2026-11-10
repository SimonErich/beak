part of 'serverpod_ir.dart';

final class _Draft {
  _Draft(this.schema, this.spy, this.db, this.resource, this.fields);
  final BeakSchemaIr schema;
  final SpyClass spy;
  final DbTable db;
  final DefinitionResource resource;
  final Map<String, SpyField> fields;
  final List<String> relationFields = [];
  final List<String> hidden = [];
}

_Draft _draftFor(
  SpyProject project,
  DbTable db,
  SpyClass spy,
  DefinitionResource resource,
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
      columns.insert(0, _fkColumn(id, 'id', resource, settings, hidden: false));
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
    labelKey: resource.labelKey,
    table: spy.table!,
    libraryPath: resource.library,
    docComment: resource.docComment,
    columns: columns,
    relations: [],
    displayColumnKey: _columnKeyOf(columns, display),
    softDeletes: softDeletes,
    timestamps: timestamps,
    managesSchema: false,
    hasBehavior: resource.hasBehavior,
    hasValidationRules: resource.hasValidationRules,
    hasPermissions: resource.hasPermissions,
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
