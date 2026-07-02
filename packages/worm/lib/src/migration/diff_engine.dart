/// Compares two schemas and reports their differences.
library;

import '../schema/table_schema.dart';
import 'schema_diff.dart';

/// Computes schema differences between two snapshots.
///
/// Treats removals and incompatible type changes as
/// destructive — flagged on the resulting [SchemaChange].
/// Adding a NOT NULL column when one was nullable before
/// is destructive too.
///
/// Static-only — cannot be instantiated.
final class DiffEngine {
  DiffEngine._();

  /// Computes a [SchemaDiff] between [from] and [to].
  ///
  /// [from] is the existing schema; [to] is the target.
  static SchemaDiff diff({
    required List<TableSchema> from,
    required List<TableSchema> to,
  }) {
    final changes = <SchemaChange>[];
    final fromByName = <String, TableSchema>{for (final t in from) t.name: t};
    final toByName = <String, TableSchema>{for (final t in to) t.name: t};

    for (final table in to) {
      final previous = fromByName[table.name];
      if (previous == null) {
        changes.add(
          SchemaChange(kind: SchemaChangeKind.addTable, table: table.name),
        );
        for (final col in table.columns) {
          changes.add(
            SchemaChange(
              kind: SchemaChangeKind.addColumn,
              table: table.name,
              column: col.name,
              newType: col.type,
              newNullable: col.nullable,
            ),
          );
        }
        continue;
      }
      changes.addAll(_diffColumns(previous, table));
    }

    for (final table in from) {
      if (!toByName.containsKey(table.name)) {
        changes.add(
          SchemaChange(
            kind: SchemaChangeKind.dropTable,
            table: table.name,
            destructive: true,
          ),
        );
      }
    }

    return SchemaDiff(changes);
  }

  static List<SchemaChange> _diffColumns(
    TableSchema previous,
    TableSchema next,
  ) {
    final changes = <SchemaChange>[];
    final previousByName = <String, ColumnSnapshot>{
      for (final c in previous.columns) c.name: c,
    };
    final nextByName = <String, ColumnSnapshot>{
      for (final c in next.columns) c.name: c,
    };

    for (final col in next.columns) {
      final prior = previousByName[col.name];
      if (prior == null) {
        changes.add(
          SchemaChange(
            kind: SchemaChangeKind.addColumn,
            table: next.name,
            column: col.name,
            newType: col.type,
            newNullable: col.nullable,
            destructive: !col.nullable,
          ),
        );
        continue;
      }
      if (prior.type != col.type) {
        changes.add(
          SchemaChange(
            kind: SchemaChangeKind.changeColumnType,
            table: next.name,
            column: col.name,
            previousType: prior.type,
            newType: col.type,
            destructive: true,
          ),
        );
      }
      if (prior.nullable != col.nullable) {
        changes.add(
          SchemaChange(
            kind: SchemaChangeKind.changeColumnNullable,
            table: next.name,
            column: col.name,
            previousNullable: prior.nullable,
            newNullable: col.nullable,
            destructive: prior.nullable && !col.nullable,
          ),
        );
      }
    }

    for (final col in previous.columns) {
      if (!nextByName.containsKey(col.name)) {
        changes.add(
          SchemaChange(
            kind: SchemaChangeKind.dropColumn,
            table: previous.name,
            column: col.name,
            previousType: col.type,
            destructive: true,
          ),
        );
      }
    }

    return changes;
  }
}
