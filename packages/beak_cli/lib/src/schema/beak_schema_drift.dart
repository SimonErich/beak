import '../introspect/beak_schema_introspection.dart';
import 'beak_schema_emitter.dart';
import 'beak_schema_ir.dart';

/// Every way the schema classes and a live database disagree.
///
/// Drift is what a migration story leaves behind: the schema class is the
/// truth the panel, the API and the generated migration all read, and once
/// the database stops matching it every one of them is wrong in a different
/// place. A missing column surfaces as a driver error on one endpoint; a
/// column the database has and no schema declares surfaces as nothing at all,
/// until someone deletes it.
///
/// Pure, and separate from the check that reports it, so `beak doctor` can
/// render these lines and a test can assert on them with no database.
///
/// ```dart
/// final drift = beakSchemaDrift(schemas: schemas, tables: introspected);
/// ```
List<String> beakSchemaDrift({
  required List<BeakSchemaIr> schemas,
  required List<IntrospectedTable> tables,
}) {
  final byTable = {for (final table in tables) table.name: table};
  final present = {
    for (final table in tables)
      table.name: {for (final column in table.columns) column.name},
  };
  final problems = <String>[];

  for (final schema in schemas) {
    final Set<String>? columns = present[schema.table];
    if (columns == null) {
      problems.add(
        '${schema.className} declares table "${schema.table}", which the '
        'database does not have',
      );
      continue;
    }

    // Columns the schema states outright.
    for (final column in schema.columns) {
      if (!columns.contains(column.columnKey)) {
        problems.add(
          '${schema.table}.${column.columnKey} is declared by '
          '${schema.className}.${column.fieldName} but missing from the '
          'database',
        );
      }
    }

    // Columns it implies. A belongs-to's key and the two bookkeeping pairs
    // are never written as fields, so nothing above would catch them.
    for (final relation in schema.relations) {
      if (relation.kind != BeakRelationKind.belongsTo) {
        continue;
      }
      final String? key = relation.foreignKey;
      if (key != null && !columns.contains(key)) {
        problems.add(
          '${schema.table}.$key backs '
          '${schema.className}.${relation.fieldName} but is missing from the '
          'database',
        );
      }
    }
    if (schema.softDeletes && !columns.contains('deleted_at')) {
      problems.add(
        '${schema.table} soft-deletes but the database has no deleted_at '
        'column',
      );
    }
    if (schema.timestamps) {
      for (final column in const ['created_at', 'updated_at']) {
        if (!columns.contains(column)) {
          problems.add(
            '${schema.table} keeps timestamps but the database has no '
            '$column column',
          );
        }
      }
    }

    // And the other direction, but only where Beak owns the table: a table
    // another system migrates is expected to carry columns Beak knows
    // nothing about, and reporting those would train people to ignore this.
    if (schema.managesSchema) {
      problems.addAll(_undeclaredColumns(schema, byTable[schema.table]!));
    }
  }

  problems.addAll(_missingPivotTables(schemas, present.keys.toSet()));
  return problems;
}

/// Columns the database has that [schema] does not account for.
List<String> _undeclaredColumns(BeakSchemaIr schema, IntrospectedTable table) {
  final accounted = {
    table.primaryKey,
    for (final column in schema.columns) column.columnKey,
    for (final relation in schema.relations)
      if (relation.kind == BeakRelationKind.belongsTo)
        if (relation.foreignKey case final String key) key,
    if (schema.softDeletes) 'deleted_at',
    if (schema.timestamps) ...['created_at', 'updated_at'],
  };
  return [
    for (final column in table.columns)
      if (!accounted.contains(column.name))
        '${table.name}.${column.name} is in the database but '
            '${schema.className} does not declare it',
  ];
}

/// Pivot tables a many-to-many needs and the database has not got.
///
/// Derived the same way the migration emitter derives them, from the same
/// helper, so a check and a generator cannot name two different tables.
List<String> _missingPivotTables(
  List<BeakSchemaIr> schemas,
  Set<String> tables,
) {
  final byClass = {for (final schema in schemas) schema.className: schema};
  final reported = <String>{};
  final problems = <String>[];
  for (final schema in schemas) {
    if (!schema.managesSchema) {
      continue;
    }
    for (final relation in schema.relations) {
      if (relation.kind != BeakRelationKind.belongsToMany) {
        continue;
      }
      final BeakSchemaIr? related = byClass[relation.relatedSchema];
      final String pivot =
          relation.pivotTable ??
          (related == null
              ? relation.relatedSchema
              : BeakSchemaEmitter.pivotTableFor(schema, related));
      if (!tables.contains(pivot) && reported.add(pivot)) {
        problems.add(
          'pivot table "$pivot" joins ${schema.className}.'
          '${relation.fieldName} but the database does not have it',
        );
      }
    }
  }
  return problems;
}
