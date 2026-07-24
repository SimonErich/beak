import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Adds every column of [model] to [table], deriving each schema type from
/// the model's typed columns — so a migration can never drift from its
/// model (column parity by construction; the schema-parity test guards it).
///
/// - The `id` column becomes the UUID primary key.
/// - Columns backing a belongs-to relationship become nullable `uuid`
///   foreign-key columns; the caller wires the FK constraints itself.
/// - Columns carrying [BeakRequired] are `NOT NULL`; the rest are nullable.
/// - Booleans default to `false`.
/// - Byte-size columns named in [bigIntColumns] use `bigInteger` so values
///   above the 32-bit range (gigabytes in bytes) do not overflow.
///
/// After the columns, `softDeletes()` is added for soft-deleting models.
void defineModelColumns(
  BlueprintTable table,
  BeakModel model, {
  Set<String> bigIntColumns = const {},
}) {
  final foreignKeys = <String>{
    for (final relation in model.relationships)
      if (relation is BeakBelongsTo) relation.foreignKey,
  };

  for (final column in model.columns) {
    if (column.key == 'id') {
      table.idUuid();
      continue;
    }
    if (foreignKeys.contains(column.key)) {
      table.uuid(column.key).makeNullable();
      continue;
    }
    final definition = switch (column) {
      BeakStringColumn(:final maxLength) => table.string(
        column.key,
        length: maxLength ?? 255,
      ),
      BeakEnumColumn() ||
      BeakColorColumn() => table.string(column.key, length: 40),
      BeakImageColumn() ||
      BeakFileColumn() => table.string(column.key, length: 512),
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakCustomColumn() => table.text(column.key),
      BeakIntColumn() =>
        bigIntColumns.contains(column.key)
            ? table.bigInteger(column.key)
            : table.integer(column.key),
      BeakDecimalColumn() => table.decimal(column.key),
      BeakBoolColumn() => table.boolean(column.key),
      BeakDateTimeColumn() => table.dateTime(column.key),
      BeakJsonColumn() => table.json(column.key),
    };
    if (column is BeakBoolColumn) {
      definition.withDefault(false);
    } else if (!column.rules.any((rule) => rule is BeakRequired)) {
      definition.makeNullable();
    }
  }

  if (model.softDeletes) {
    table.softDeletes();
  }
}

/// Creates a keyless pivot table [name] joining [leftColumn] → [leftTable]
/// and [rightColumn] → [rightTable], with a unique pair and cascading
/// foreign keys — the shared shape of every many-to-many join.
void definePivotTable(
  BlueprintTable table, {
  required String leftColumn,
  required String leftTable,
  required String rightColumn,
  required String rightTable,
}) {
  table.uuid(leftColumn);
  table.uuid(rightColumn);
  table.unique([leftColumn, rightColumn]);
  table.foreign(
    column: leftColumn,
    references: 'id',
    onTable: leftTable,
    onDelete: OnDelete.cascade,
  );
  table.foreign(
    column: rightColumn,
    references: 'id',
    onTable: rightTable,
    onDelete: OnDelete.cascade,
  );
}
