import '../introspect/beak_schema_introspection.dart';
import 'beak_schema_emitter.dart';
import 'beak_schema_ir.dart';

/// One way a schema class and the database disagree.
///
/// Sealed rather than a string, because two callers want different things
/// from the same comparison: `beak doctor` renders [message], and
/// `beak make:migration --from-drift` needs the column it has to add.
sealed class BeakDrift {
  const BeakDrift();

  /// The table this is about.
  String get table;

  /// The difference, in one line.
  String get message;
}

/// A table a schema declares and the database has not got.
final class BeakMissingTable extends BeakDrift {
  /// Records that [schema]'s table is absent.
  const BeakMissingTable(this.schema);

  /// The schema that declares it.
  final BeakSchemaIr schema;

  @override
  String get table => schema.table;

  @override
  String get message =>
      '${schema.className} declares table "${schema.table}", which the '
      'database does not have';
}

/// Why a schema expects a column the table has not got.
///
/// Only [BeakMissingColumnCause.declared] carries a field, and only a field
/// can be added back mechanically: the other three are shapes the schema
/// implies, and adding them means adding the flag or the relationship too.
enum BeakMissingColumnCause {
  /// A field on the schema class declares it.
  declared,

  /// A belongs-to relationship is backed by it.
  foreignKey,

  /// `@Resource(softDeletes: true)` implies it.
  softDelete,

  /// `@Resource(timestamps: true)` implies it.
  timestamp,
}

/// A column a schema expects and the table has not got.
final class BeakMissingColumn extends BeakDrift {
  /// Records that [columnKey] is absent from [schema]'s table.
  const BeakMissingColumn({
    required this.schema,
    required this.columnKey,
    required this.cause,
    this.column,
    this.relation,
  });

  /// The schema that expects it.
  final BeakSchemaIr schema;

  /// The storage column that is missing.
  final String columnKey;

  /// Why the schema expects it.
  final BeakMissingColumnCause cause;

  /// The declared field, when [cause] is [BeakMissingColumnCause.declared].
  final BeakColumnIr? column;

  /// The relationship, when [cause] is [BeakMissingColumnCause.foreignKey].
  final BeakRelationIr? relation;

  @override
  String get table => schema.table;

  @override
  String get message => switch (cause) {
    BeakMissingColumnCause.declared =>
      '${schema.table}.$columnKey is declared by ${schema.className}.'
          '${column?.fieldName} but missing from the database',
    BeakMissingColumnCause.foreignKey =>
      '${schema.table}.$columnKey backs ${schema.className}.'
          '${relation?.fieldName} but is missing from the database',
    BeakMissingColumnCause.softDelete =>
      '${schema.table} soft-deletes but the database has no $columnKey column',
    BeakMissingColumnCause.timestamp =>
      '${schema.table} keeps timestamps but the database has no $columnKey '
          'column',
  };
}

/// A column the table has that no schema accounts for.
final class BeakUndeclaredColumn extends BeakDrift {
  /// Records that [columnKey] is present but undeclared.
  const BeakUndeclaredColumn({required this.schema, required this.columnKey});

  /// The schema that owns the table.
  final BeakSchemaIr schema;

  /// The column the database has.
  final String columnKey;

  @override
  String get table => schema.table;

  @override
  String get message =>
      '${schema.table}.$columnKey is in the database but '
      '${schema.className} does not declare it';
}

/// A pivot table a many-to-many needs and the database has not got.
final class BeakMissingPivot extends BeakDrift {
  /// Records that [table] is absent.
  const BeakMissingPivot({
    required this.table,
    required this.schema,
    required this.relation,
  });

  @override
  final String table;

  /// The schema on the owning side.
  final BeakSchemaIr schema;

  /// The relationship that needs it.
  final BeakRelationIr relation;

  @override
  String get message =>
      'pivot table "$table" joins ${schema.className}.${relation.fieldName} '
      'but the database does not have it';
}

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
List<BeakDrift> beakSchemaDrift({
  required List<BeakSchemaIr> schemas,
  required List<IntrospectedTable> tables,
}) {
  final byTable = {for (final table in tables) table.name: table};
  final present = {
    for (final table in tables)
      table.name: {for (final column in table.columns) column.name},
  };
  final problems = <BeakDrift>[];

  for (final schema in schemas) {
    final Set<String>? columns = present[schema.table];
    if (columns == null) {
      problems.add(BeakMissingTable(schema));
      continue;
    }

    // Columns the schema states outright.
    for (final column in schema.columns) {
      if (!columns.contains(column.columnKey)) {
        problems.add(
          BeakMissingColumn(
            schema: schema,
            columnKey: column.columnKey,
            cause: BeakMissingColumnCause.declared,
            column: column,
          ),
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
          BeakMissingColumn(
            schema: schema,
            columnKey: key,
            cause: BeakMissingColumnCause.foreignKey,
            relation: relation,
          ),
        );
      }
    }
    if (schema.softDeletes && !columns.contains('deleted_at')) {
      problems.add(
        BeakMissingColumn(
          schema: schema,
          columnKey: 'deleted_at',
          cause: BeakMissingColumnCause.softDelete,
        ),
      );
    }
    if (schema.timestamps) {
      for (final column in const ['created_at', 'updated_at']) {
        if (!columns.contains(column)) {
          problems.add(
            BeakMissingColumn(
              schema: schema,
              columnKey: column,
              cause: BeakMissingColumnCause.timestamp,
            ),
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
List<BeakDrift> _undeclaredColumns(
  BeakSchemaIr schema,
  IntrospectedTable table,
) {
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
        BeakUndeclaredColumn(schema: schema, columnKey: column.name),
  ];
}

/// Pivot tables a many-to-many needs and the database has not got.
///
/// Derived the same way the migration emitter derives them, from the same
/// helper, so a check and a generator cannot name two different tables.
List<BeakDrift> _missingPivotTables(
  List<BeakSchemaIr> schemas,
  Set<String> tables,
) {
  final byClass = {for (final schema in schemas) schema.className: schema};
  final reported = <String>{};
  final problems = <BeakDrift>[];
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
          BeakMissingPivot(table: pivot, schema: schema, relation: relation),
        );
      }
    }
  }
  return problems;
}
