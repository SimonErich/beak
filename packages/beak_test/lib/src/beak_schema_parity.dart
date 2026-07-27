import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// A column the database actually has, as reported by a schema reader.
///
/// Deliberately minimal: parity is about *presence*, and a richer shape would
/// make this assertion couple to one ORM's introspection API.
typedef BeakSchemaColumns = Map<String, Set<String>>;

/// Asserts that every model in [registry] has a table with the columns it
/// declares, and vice versa.
///
/// Both demo apps had written this test, separately, because nothing asserts
/// model ⟷ migration agreement on its own — the exact gap
/// `WORM_MISSING_FEATURES.md` §3d names, and which it correctly concluded
/// cannot live in worm because the metadata source is a Beak concept.
///
/// [actual] maps table name to the column names the schema has. Get it from
/// whatever your stack can introspect; the assertion does not care how.
///
/// ```dart
/// test('every model has its table', () async {
///   expectSchemaParity(
///     registry: buildRegistry(),
///     actual: await introspect(adapter),
///   );
/// });
/// ```
void expectSchemaParity({
  required BeakModelRegistry registry,
  required BeakSchemaColumns actual,
  Set<String> ignoreTables = const {},
  Set<String> ignoreColumns = const {},
}) {
  final problems = beakSchemaParityProblems(
    registry: registry,
    actual: actual,
    ignoreTables: ignoreTables,
    ignoreColumns: ignoreColumns,
  );
  if (problems.isNotEmpty) {
    fail(
      'Schema parity failed:\n${problems.map((line) => '  - $line').join('\n')}',
    );
  }
}

/// Every way [registry] and [actual] disagree, in reading order.
///
/// The pure half of [expectSchemaParity]: it returns the problems instead of
/// failing on them, so a tool that is not a test — `beak doctor` reporting
/// drift against a live database — can render them as its own diagnostics
/// rather than calling `fail` from `package:test`.
///
/// ```dart
/// for (final problem in beakSchemaParityProblems(
///   registry: buildBeakRegistry(),
///   actual: await adapter.introspectSchema(),
/// )) {
///   print(problem);
/// }
/// ```
List<String> beakSchemaParityProblems({
  required BeakModelRegistry registry,
  required BeakSchemaColumns actual,
  Set<String> ignoreTables = const {},
  Set<String> ignoreColumns = const {},
}) {
  final problems = <String>[];

  for (final model in registry.all) {
    if (ignoreTables.contains(model.table)) {
      continue;
    }
    final Set<String>? columns = actual[model.table];
    if (columns == null) {
      problems.add(
        'table "${model.table}" is missing — ${model.runtimeType} declares it '
        'but the schema has no such table',
      );
      continue;
    }
    for (final column in model.columns) {
      if (ignoreColumns.contains(column.key)) {
        continue;
      }
      if (!columns.contains(column.key)) {
        problems.add(
          '${model.table}.${column.key} is declared by the model but missing '
          'from the schema',
        );
      }
    }
    // A belongs-to's foreign key is a column the model implies rather than
    // declares, so check it separately.
    for (final relation in model.relationships) {
      if (relation is! BeakBelongsTo) {
        continue;
      }
      if (!columns.contains(relation.foreignKey)) {
        problems.add(
          '${model.table}.${relation.foreignKey} backs relationship '
          '"${relation.key}" but is missing from the schema',
        );
      }
    }
    if (model.softDeletes && !columns.contains('deleted_at')) {
      problems.add(
        '${model.table} soft-deletes but the schema has no deleted_at column',
      );
    }
  }
  return problems;
}

/// Asserts that every table in [actual] is claimed by a model in [registry].
///
/// The other direction of parity: a table nothing models is either dead
/// weight or a resource someone forgot to surface. Framework bookkeeping
/// tables are excluded by default.
void expectNoOrphanTables({
  required BeakModelRegistry registry,
  required BeakSchemaColumns actual,
  Set<String> ignoreTables = const {},
}) {
  final modelled = {for (final model in registry.all) model.table};
  final pivots = {
    for (final model in registry.all)
      for (final relation in model.relationships)
        if (relation is BeakBelongsToMany) relation.pivotTable,
  };
  final orphans = [
    for (final table in actual.keys)
      if (!modelled.contains(table) &&
          !pivots.contains(table) &&
          !ignoreTables.contains(table) &&
          !frameworkTables.contains(table))
        table,
  ]..sort();

  if (orphans.isNotEmpty) {
    fail(
      'Tables with no model: ${orphans.join(', ')}.\n'
      'Add a model, or list them in ignoreTables if they are intentional.',
    );
  }
}

/// Bookkeeping tables migration frameworks create, never modelled by an app.
const Set<String> frameworkTables = {
  'migrations',
  'worm_migrations',
  'schema_migrations',
  'ar_internal_metadata',
  'django_migrations',
  'flyway_schema_history',
  '_prisma_migrations',
};
