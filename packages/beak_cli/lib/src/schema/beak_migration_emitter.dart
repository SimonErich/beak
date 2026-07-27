import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import 'beak_schema_ir.dart';

/// One migration Beak wrote, and where it goes.
final class BeakMigrationFile {
  /// Creates a migration file description.
  const BeakMigrationFile({
    required this.path,
    required this.contents,
    required this.table,
  });

  /// Project-relative path.
  final String path;

  /// The Dart source.
  final String contents;

  /// The table it creates — a real table, or a pivot.
  final String table;
}

/// Writes the migrations a project's schemas imply but does not have.
///
/// A generated migration is a starting point the project then owns: it is
/// written once, committed, and never regenerated. What is derived is the
/// *content* — `BeakBlueprint` reads the same `BeakModel` the API and the
/// panel read, so the table and the resource cannot drift — and not the
/// decision to apply one. Migrations stay explicit files you review.
///
/// This exists because a scaffolded project used to start a server whose
/// every endpoint failed on a missing table, and `beak doctor` reported all
/// clear.
abstract final class BeakMigrationEmitter {
  /// The migrations [schemas] need that [coveredTables] does not already
  /// create.
  ///
  /// Emitted in dependency order — a belongs-to target before the table that
  /// references it — with [now] advanced one second per file, because worm
  /// runs migrations in the order they are registered and `beak prepare`
  /// registers them by declared name. Without that, a foreign key would
  /// reference a table that does not exist yet.
  ///
  /// A schema declaring `managesSchema: false` is skipped: another system
  /// owns that table.
  static List<BeakMigrationFile> missing({
    required List<BeakDiscoveredSymbol> models,
    required List<BeakSchemaIr> schemas,
    required Set<String> coveredTables,
    required DateTime now,
  }) {
    final owned = <BeakSchemaIr>[
      for (final schema in schemas)
        if (schema.managesSchema) schema,
    ];
    final byClass = {for (final schema in owned) schema.className: schema};
    // A table another system owns is named by a schema that opts out; a
    // hand-written model has no way to say so, and does not need one — it
    // simply has a migration already, or it does not.
    final disowned = <String>{
      for (final schema in schemas)
        if (!schema.managesSchema) schema.table,
    };
    final schemaTables = {for (final schema in owned) schema.table};

    final files = <BeakMigrationFile>[];
    var stamp = now;
    String nextTimestamp() {
      final at = stamp;
      stamp = stamp.add(const Duration(seconds: 1));
      return _timestampOf(at);
    }

    // Schemas first, in dependency order — only they declare relationships,
    // so only they can be ordered. Then any hand-written model, which is the
    // documented escape hatch and equally broken without a table.
    for (final schema in _inDependencyOrder(owned, byClass)) {
      if (coveredTables.contains(schema.table)) {
        continue;
      }
      files.add(
        BeakMigrationFile(
          path: 'lib/migrations/create_${schema.table}_table.dart',
          contents: _tableMigration(
            table: schema.table,
            modelClass: schema.modelClass,
            importPath: schema.libraryPath,
            timestamp: nextTimestamp(),
          ),
          table: schema.table,
        ),
      );
    }
    for (final model in models) {
      final String? table = model.table;
      if (table == null ||
          schemaTables.contains(table) ||
          disowned.contains(table) ||
          coveredTables.contains(table)) {
        continue;
      }
      files.add(
        BeakMigrationFile(
          path: 'lib/migrations/create_${table}_table.dart',
          contents: _tableMigration(
            table: table,
            modelClass: model.name,
            importPath: model.importPath,
            timestamp: nextTimestamp(),
          ),
          table: table,
        ),
      );
    }

    for (final (schema, relation) in _pivotsOf(owned)) {
      final String pivot = relation.pivotTable!;
      // Either the table name, or the relation constant a hand-written
      // `createPivot` names it through.
      final bool covered =
          coveredTables.contains(pivot) ||
          coveredTables.contains(
            '${schema.relationsClass}.${relation.fieldName}',
          );
      if (covered) {
        continue;
      }
      files.add(
        BeakMigrationFile(
          path: 'lib/migrations/create_${pivot}_table.dart',
          contents: _pivotMigration(schema, relation, nextTimestamp()),
          table: pivot,
        ),
      );
    }
    return files;
  }

  /// [schemas] ordered so every belongs-to target precedes the schema that
  /// references it.
  ///
  /// A stable topological walk: a cycle (two tables pointing at each other)
  /// cannot be ordered, so the remainder keeps declaration order and the
  /// foreign key is left for the project to add in a follow-up migration.
  static List<BeakSchemaIr> _inDependencyOrder(
    List<BeakSchemaIr> schemas,
    Map<String, BeakSchemaIr> byClass,
  ) {
    final ordered = <BeakSchemaIr>[];
    final placed = <String>{};

    void visit(BeakSchemaIr schema, Set<String> visiting) {
      if (placed.contains(schema.className) ||
          !visiting.add(schema.className)) {
        return;
      }
      for (final relation in schema.relations) {
        if (relation.kind != BeakRelationKind.belongsTo) {
          continue;
        }
        if (byClass[relation.relatedSchema] case final BeakSchemaIr target) {
          visit(target, visiting);
        }
      }
      visiting.remove(schema.className);
      if (placed.add(schema.className)) {
        ordered.add(schema);
      }
    }

    for (final schema in schemas) {
      visit(schema, <String>{});
    }
    return ordered;
  }

  /// Every many-to-many, once per pivot table.
  ///
  /// Only the declaring side appears in `schema.relations`, so a pivot cannot
  /// be reached twice — but a project may declare both sides explicitly, and
  /// two migrations creating one table would fail on the second.
  static List<(BeakSchemaIr, BeakRelationIr)> _pivotsOf(
    List<BeakSchemaIr> schemas,
  ) {
    final seen = <String>{};
    return <(BeakSchemaIr, BeakRelationIr)>[
      for (final schema in schemas)
        for (final relation in schema.relations)
          if (relation.kind == BeakRelationKind.belongsToMany &&
              relation.pivotTable != null &&
              seen.add(relation.pivotTable!))
            (schema, relation),
    ];
  }

  static String _tableMigration({
    required String table,
    required String modelClass,
    required String importPath,
    required String timestamp,
  }) {
    final String className = 'Create${_pascalOf(table)}Table';
    return BeakEmitters.format('''
import 'package:beak/migrations.dart';

import '../$importPath';

/// Creates the $table table.
///
/// Derived from $modelClass the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class $className extends Migration {
  /// Creates the migration.
  const $className();

  @override
  String get name => '${timestamp}_create_${table}_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('$table', (table) {
      BeakBlueprint.defineColumns(table, const $modelClass());
      BeakBlueprint.defineForeignKeys(table, const $modelClass());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('$table', ifExists: true);
}
''');
  }

  static String _pivotMigration(
    BeakSchemaIr schema,
    BeakRelationIr relation,
    String timestamp,
  ) {
    final String pivot = relation.pivotTable!;
    final String className = 'Create${_pascalOf(pivot)}Table';
    return BeakEmitters.format('''
import 'package:beak/migrations.dart';

import '../${schema.libraryPath}';

/// Creates the $pivot pivot joining ${schema.table} and its
/// ${relation.key}.
final class $className extends Migration {
  /// Creates the migration.
  const $className();

  @override
  String get name => '${timestamp}_create_${pivot}_table';

  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    ${schema.relationsClass}.${relation.fieldName},
    ownerTable: '${schema.table}',
  );

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('$pivot', ifExists: true);
}
''');
  }

  /// `order_items` -> `OrderItems`, for a migration class name.
  static String _pascalOf(String table) => table
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();

  /// `20260727_143012`, sortable and readable.
  static String _timestampOf(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}${two(at.month)}${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }
}
