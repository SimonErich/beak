/// Fluent schema builder for migrations.
library;

import '../exception/schema_definition_exception.dart';
import 'column_definition.dart';
import 'column_type.dart';
import 'foreign_key_definition.dart';
import 'index_definition.dart';
import 'on_delete.dart';

/// Operation performed by a [Blueprint].
enum BlueprintOperation {
  /// Create a new table.
  create,

  /// Alter an existing table.
  alter,

  /// Drop an existing table.
  drop,
}

/// Fluent table builder used inside a [Blueprint] callback.
///
/// Adds columns, indexes, and foreign keys with chainable
/// modifiers.
final class BlueprintTable {
  /// Creates a [BlueprintTable] for [tableName].
  BlueprintTable(this.tableName);

  /// The target table.
  final String tableName;

  /// Columns defined on the table.
  final List<ColumnDefinition> columns = <ColumnDefinition>[];

  /// Indexes defined on the table.
  final List<IndexDefinition> indexes = <IndexDefinition>[];

  /// Foreign key constraints defined on the table.
  final List<ForeignKeyDefinition> foreignKeys = <ForeignKeyDefinition>[];

  /// Columns marked for removal during ALTER.
  final List<String> droppedColumns = <String>[];

  /// Index names marked for removal during ALTER.
  final List<String> droppedIndexes = <String>[];

  /// Foreign-key constraint names marked for removal during ALTER.
  final List<String> droppedForeignKeys = <String>[];

  /// Columns being added, in declaration order.
  List<ColumnDefinition> get addedColumns => <ColumnDefinition>[
    for (final column in columns)
      if (!column.isChange) column,
  ];

  /// Columns being modified, in declaration order.
  List<ColumnDefinition> get changedColumns => <ColumnDefinition>[
    for (final column in columns)
      if (column.isChange) column,
  ];

  ColumnDefinition _add(ColumnDefinition column) {
    columns.add(column);
    return column;
  }

  /// Adds a `string` column.
  ColumnDefinition string(String name, {int length = 255}) => _add(
    ColumnDefinition(name: name, type: ColumnType.string, length: length),
  );

  /// Adds an `integer` column.
  ColumnDefinition integer(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.integer));

  /// Adds a `smallInteger` column.
  ColumnDefinition smallInteger(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.smallInteger));

  /// Adds a `bigInteger` column.
  ColumnDefinition bigInteger(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.bigInteger));

  /// Adds a `decimal` column with [precision] and [scale].
  ColumnDefinition decimal(String name, {int precision = 10, int scale = 2}) =>
      _add(
        ColumnDefinition(
          name: name,
          type: ColumnType.decimal,
          precision: precision,
          scale: scale,
        ),
      );

  /// Adds a `boolean` column.
  ColumnDefinition boolean(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.boolean));

  /// Adds a `date` column.
  ColumnDefinition date(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.date));

  /// Adds a `dateTime` column.
  ColumnDefinition dateTime(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.dateTime));

  /// Adds a `uuid` column.
  ColumnDefinition uuid(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.uuid));

  /// Adds a `json` column.
  ColumnDefinition json(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.json));

  /// Adds a `jsonb` column.
  ColumnDefinition jsonb(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.jsonb));

  /// Adds a `text` column.
  ColumnDefinition text(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.text));

  /// Adds a `binary` column.
  ColumnDefinition binary(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.binary));

  /// Adds a `doublePrecision` column.
  ColumnDefinition doublePrecision(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.doublePrecision));

  /// Adds an `enumType` column constrained to [values].
  ColumnDefinition enumColumn(String name, List<String> values) => _add(
    ColumnDefinition(name: name, type: ColumnType.enumType, enumValues: values),
  );

  /// Adds a `tsvector` column.
  ColumnDefinition tsvector(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.tsvector));

  /// Adds a `time` column.
  ColumnDefinition time(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.time));

  /// Adds an `interval` column.
  ColumnDefinition interval(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.interval));

  /// Adds an `inet` column.
  ColumnDefinition inet(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.inet));

  /// Adds a `macaddr` column.
  ColumnDefinition macaddr(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.macaddr));

  /// Adds a `point` column.
  ColumnDefinition point(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.point));

  /// Adds a `line` column.
  ColumnDefinition line(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.line));

  /// Adds a `box` column.
  ColumnDefinition box(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.box));

  /// Adds a `money` column.
  ColumnDefinition money(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.money));

  /// Adds a `bit` column of [length].
  ColumnDefinition bit(String name, {int length = 1}) =>
      _add(ColumnDefinition(name: name, type: ColumnType.bit, length: length));

  /// Adds an `xml` column.
  ColumnDefinition xml(String name) =>
      _add(ColumnDefinition(name: name, type: ColumnType.xml));

  /// Adds an `array` column of [elementType].
  ColumnDefinition array(String name, ColumnType elementType) => _add(
    ColumnDefinition(
      name: name,
      type: ColumnType.array,
      elementType: elementType,
    ),
  );

  /// Convenience for `createdAt` and `updatedAt` columns.
  void timestamps() {
    dateTime('created_at').makeNullable();
    dateTime('updated_at').makeNullable();
  }

  /// Convenience for the `deletedAt` soft-delete column.
  void softDeletes() {
    dateTime('deleted_at').makeNullable();
  }

  /// Convenience for an auto-incrementing `id` primary key.
  ColumnDefinition idIncrements({String name = 'id'}) {
    final column = integer(name)
      ..primary()
      ..autoIncrementing();
    return column;
  }

  /// Convenience for a UUID primary key column.
  ColumnDefinition idUuid({String name = 'id'}) {
    final column = uuid(name)..primary();
    return column;
  }

  /// Spec alias for [idUuid] — declares a UUID primary key
  /// column named `id`.
  ///
  /// `table.id()` matches the spec example surface.
  ColumnDefinition id({String name = 'id'}) => idUuid(name: name);

  /// Spec alias for [idIncrements] — declares an auto-
  /// incrementing integer primary key column named `id`.
  ///
  /// `table.intId()` matches the spec example surface.
  ColumnDefinition intId({String name = 'id'}) => idIncrements(name: name);

  /// Marks [columnName] for removal during ALTER.
  void dropColumn(String columnName) {
    droppedColumns.add(columnName);
  }

  /// Marks the index named [indexName] for removal during ALTER.
  void dropIndex(String indexName) {
    droppedIndexes.add(indexName);
  }

  /// Marks the foreign-key constraint named [constraintName] for removal
  /// during ALTER.
  void dropForeign(String constraintName) {
    droppedForeignKeys.add(constraintName);
  }

  /// Adds an index over [columns].
  IndexDefinition index(
    List<String> columns, {
    String? name,
    bool unique = false,
    IndexKind kind = IndexKind.btree,
    String? where,
  }) {
    final indexName = name ?? '${tableName}_${columns.join('_')}_idx';
    // Declaring the same index twice is normal once anything derives indexes
    // from a model: a migration may also name the one on a foreign key. Two
    // definitions with one name is either the same index — in which case the
    // second is redundant — or a mistake worth naming.
    for (final existing in indexes) {
      if (existing.name != indexName) {
        continue;
      }
      final identical =
          _sameColumns(existing.columns, columns) &&
          existing.unique == unique &&
          existing.kind == kind &&
          existing.partialWhere == where;
      if (identical) {
        return existing;
      }
      throw SchemaDefinitionException(
        table: tableName,
        operation: 'index',
        message:
            'Two different indexes would both be named "$indexName". A '
            'unique, partial or differently-typed index over the same '
            'columns is a different index, and no database accepts two under '
            'one name — give one of them an explicit name.',
      );
    }
    final def = IndexDefinition(
      name: indexName,
      columns: columns,
      unique: unique,
      kind: kind,
      partialWhere: where,
    );
    indexes.add(def);
    return def;
  }

  /// Whether [a] and [b] cover the same columns in the same order.
  static bool _sameColumns(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Adds a unique index over [columns].
  IndexDefinition unique(List<String> columns, {String? name}) =>
      index(columns, name: name, unique: true);

  /// Adds a single-column foreign key constraint on [column].
  ForeignKeyDefinition foreign({
    required String column,
    required String references,
    required String onTable,
    OnDelete onDelete = OnDelete.restrict,
    String? name,
  }) {
    final def = ForeignKeyDefinition(
      column: column,
      referencedTable: onTable,
      referencedColumn: references,
      onDelete: onDelete,
      name: name,
    );
    foreignKeys.add(def);
    return def;
  }

  /// Adds a composite (multi-column) foreign key constraint.
  ///
  /// [columns] are the local columns; [referencedColumns] are the
  /// corresponding columns on [onTable], matched by index. The two
  /// lists must have the same length.
  ForeignKeyDefinition foreignComposite({
    required List<String> columns,
    required List<String> referencedColumns,
    required String onTable,
    OnDelete onDelete = OnDelete.restrict,
    String? name,
  }) {
    final def = ForeignKeyDefinition.composite(
      columns: columns,
      referencedTable: onTable,
      referencedColumns: referencedColumns,
      onDelete: onDelete,
      name: name,
    );
    foreignKeys.add(def);
    return def;
  }
}

/// A fluent schema operation builder.
///
/// Use the named constructors [Blueprint.create], [Blueprint.alter],
/// and [Blueprint.drop] to capture a single DDL operation. Each
/// instance is consumed once and is the unit of work the
/// migration runner executes.
final class Blueprint {
  Blueprint._({
    required this.tableName,
    required this.operation,
    required this.table,
  });

  /// Creates a `CREATE TABLE` blueprint.
  factory Blueprint.create(
    String tableName,
    void Function(BlueprintTable table) build,
  ) {
    final table = BlueprintTable(tableName);
    build(table);
    return Blueprint._(
      tableName: tableName,
      operation: BlueprintOperation.create,
      table: table,
    );
  }

  /// Creates an `ALTER TABLE` blueprint.
  factory Blueprint.alter(
    String tableName,
    void Function(BlueprintTable table) build,
  ) {
    final table = BlueprintTable(tableName);
    build(table);
    return Blueprint._(
      tableName: tableName,
      operation: BlueprintOperation.alter,
      table: table,
    );
  }

  /// Creates a `DROP TABLE` blueprint.
  factory Blueprint.drop(String tableName) => Blueprint._(
    tableName: tableName,
    operation: BlueprintOperation.drop,
    table: BlueprintTable(tableName),
  );

  /// The target table.
  final String tableName;

  /// The DDL operation.
  final BlueprintOperation operation;

  /// The accumulated table definition.
  final BlueprintTable table;
}
