import '../project/beak_emitters.dart';
import 'beak_schema_drift.dart';
import 'beak_schema_ir.dart';

/// Writes the migration that closes the gap between the models and a database.
///
/// A generated create migration reads its columns from the model at runtime
/// (`BeakBlueprint.defineColumns`), so a field added to a schema class reaches
/// a *fresh* database with no second edit. A database that has already run
/// that migration is the case this exists for: the column has to be added by
/// an `alter`, and the only way to know which columns are missing is to look.
///
/// So this takes drift, which is a fact about a live database, rather than
/// reading the migrations. Nothing static could answer the question: no
/// migration in a Beak project names its columns.
abstract final class BeakDriftMigrationEmitter {
  /// The drift this can write a migration for.
  ///
  /// A column a *field* declares, and nothing else. A missing table means the
  /// resource was never migrated at all, which `beak prepare` already writes
  /// a create migration for; a missing `deleted_at` means the flag was turned
  /// on, which changes more than the table; and a column the database has and
  /// no schema declares is a decision, not a defect.
  static List<BeakMissingColumn> addable(List<BeakDrift> drift) => [
    for (final problem in drift)
      if (problem case BeakMissingColumn(
        cause: BeakMissingColumnCause.declared,
      ))
        problem,
  ];

  /// The migration body for [drift], grouped by table.
  ///
  /// Returns `null` when nothing in [drift] can be added, so the caller can
  /// say so rather than writing an empty migration.
  static String? emit({
    required String className,
    required String timestamp,
    required String description,
    required List<BeakDrift> drift,
  }) {
    final List<BeakMissingColumn> columns = addable(drift);
    if (columns.isEmpty) {
      return null;
    }

    final byTable = <String, List<BeakMissingColumn>>{};
    for (final column in columns) {
      (byTable[column.table] ??= []).add(column);
    }
    final tables = byTable.keys.toList()..sort();

    final imports = <String>{
      for (final table in tables)
        "import '../models/${_libraryOf(byTable[table]!.first.schema)}';",
    };

    final buffer = StringBuffer()
      ..writeln("import 'package:beak/migrations.dart';")
      ..writeln();
    for (final import in imports.toList()..sort()) {
      buffer.writeln(import);
    }
    buffer
      ..writeln()
      ..writeln('/// $description.')
      ..writeln('///')
      ..writeln('/// Written from the difference between the schema classes')
      ..writeln('/// and the database, and yours from now on.')
      ..writeln('final class $className extends Migration {')
      ..writeln('  /// Creates the migration.')
      ..writeln('  const $className();')
      ..writeln()
      ..writeln('  @override')
      ..writeln("  String get name => '${timestamp}_${_snakeOf(className)}';")
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Future<void> upSchema(Schema schema) async {');
    for (final table in tables) {
      buffer.writeln("    await schema.alter('$table', (table) {");
      for (final column in byTable[table]!) {
        // The same mapping the create migration used, so a column added here
        // and a column created there cannot become different columns.
        buffer.writeln(
          '      BeakBlueprint.defineColumn('
          'table, ${column.schema.columnsClass}.${column.column?.fieldName});',
        );
      }
      buffer.writeln('    });');
    }
    buffer
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Future<void> downSchema(Schema schema) async {');
    for (final table in tables) {
      buffer.writeln("    await schema.alter('$table', (table) {");
      for (final column in byTable[table]!) {
        buffer.writeln("      table.dropColumn('${column.columnKey}');");
      }
      buffer.writeln('    });');
    }
    buffer
      ..writeln('  }')
      ..writeln('}');
    return BeakEmitters.format(buffer.toString());
  }

  /// The `lib/models/`-relative library a schema is declared in.
  static String _libraryOf(BeakSchemaIr schema) =>
      schema.libraryPath.startsWith('models/')
      ? schema.libraryPath.substring('models/'.length)
      : schema.libraryPath;

  /// `AddStockToProducts` -> `add_stock_to_products`.
  static String _snakeOf(String className) => className
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toLowerCase();
}
