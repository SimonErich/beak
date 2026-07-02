/// Fluent schema builder for migrations.
library;

import 'column_definition.dart';
import 'column_type.dart';
import 'foreign_key_definition.dart';
import 'index_definition.dart';
import 'on_delete.dart';
import 'type_mapper.dart';

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

  /// Adds an index over [columns].
  IndexDefinition index(
    List<String> columns, {
    String? name,
    bool unique = false,
    IndexKind kind = IndexKind.btree,
    String? where,
  }) {
    final indexName = name ?? '${tableName}_${columns.join('_')}_idx';
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

  /// Renders the blueprint as PostgreSQL DDL.
  String toSql() => switch (operation) {
    BlueprintOperation.create => _renderCreate(),
    BlueprintOperation.alter => _renderAlter(),
    BlueprintOperation.drop => 'DROP TABLE IF EXISTS "$tableName";',
  };

  String _renderCreate() {
    final buffer = StringBuffer('CREATE TABLE "$tableName" (')..write('\n');
    final lines = <String>[
      for (final col in table.columns) _renderColumn(col),
      for (final fk in table.foreignKeys) _renderForeignKey(fk),
    ];
    buffer
      ..writeAll(lines, ',\n')
      ..write('\n);');
    for (final idx in table.indexes) {
      buffer
        ..write('\n')
        ..write(_renderIndex(idx));
    }
    return buffer.toString();
  }

  String _renderAlter() {
    final parts = <String>[
      for (final col in table.columns)
        'ADD COLUMN ${_renderColumn(col).trim()}',
      for (final dropped in table.droppedColumns) 'DROP COLUMN "$dropped"',
    ];
    if (parts.isEmpty) return '-- empty alter';
    return 'ALTER TABLE "$tableName" ${parts.join(', ')};';
  }

  String _renderColumn(ColumnDefinition col) {
    final sqlType = TypeMapper.toSqlType(
      col.type,
      length: col.length,
      precision: col.precision,
      scale: col.scale,
      elementType: col.elementType,
    );
    final buffer = StringBuffer('  "${col.name}" $sqlType');
    if (col.autoIncrement) buffer.write(' GENERATED ALWAYS AS IDENTITY');
    if (col.isPrimaryKey) buffer.write(' PRIMARY KEY');
    if (col.unique) buffer.write(' UNIQUE');
    if (!col.nullable && !col.isPrimaryKey) buffer.write(' NOT NULL');
    final defaultValue = col.defaultValue;
    if (defaultValue != null) {
      buffer.write(' DEFAULT ${_renderDefault(defaultValue)}');
    }
    return buffer.toString();
  }

  String _renderDefault(Object value) => switch (value) {
    final bool b => b ? 'TRUE' : 'FALSE',
    final num n => '$n',
    _ => "'$value'",
  };

  String _renderForeignKey(ForeignKeyDefinition fk) {
    final locals = fk.columns.map((c) => '"$c"').join(', ');
    final remotes = fk.referencedColumns.map((c) => '"$c"').join(', ');
    final buffer = StringBuffer('  FOREIGN KEY ($locals) ')
      ..write('REFERENCES "${fk.referencedTable}"')
      ..write('($remotes)')
      ..write(' ON DELETE ${_onDeleteSql(fk.onDelete)}');
    return buffer.toString();
  }

  String _onDeleteSql(OnDelete action) => switch (action) {
    OnDelete.cascade => 'CASCADE',
    // ormCascade is honored at runtime by ActiveRecord.delete; the
    // database-level FK is rendered as NO ACTION because the ORM
    // walks every child before issuing the parent delete.
    OnDelete.ormCascade => 'NO ACTION',
    OnDelete.restrict => 'RESTRICT',
    OnDelete.setNull => 'SET NULL',
    OnDelete.setDefault => 'SET DEFAULT',
    OnDelete.noAction => 'NO ACTION',
  };

  String _renderIndex(IndexDefinition idx) {
    final cols = idx.columns.map((c) => '"$c"').join(', ');
    final unique = idx.unique ? 'UNIQUE ' : '';
    final where = idx.partialWhere != null ? ' WHERE ${idx.partialWhere}' : '';
    return 'CREATE ${unique}INDEX "${idx.name}" '
        'ON "$tableName" USING ${idx.kind.name} ($cols)$where;';
  }

  /// Renders the blueprint as a MongoDB description document.
  Map<String, Object?> toMongo() => <String, Object?>{
    'operation': operation.name,
    'collection': tableName,
    if (operation != BlueprintOperation.drop)
      'fields': <Map<String, Object?>>[
        for (final col in table.columns)
          <String, Object?>{
            'name': col.name,
            'bsonType': TypeMapper.toMongoType(col.type),
            'required': !col.nullable,
          },
      ],
    if (table.indexes.isNotEmpty)
      'indexes': <Map<String, Object?>>[
        for (final idx in table.indexes) idx.toMap(),
      ],
  };
}
