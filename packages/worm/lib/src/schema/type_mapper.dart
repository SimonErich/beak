/// SQL and MongoDB type mappings for [ColumnType].
library;

import 'column_type.dart';

/// Maps abstract [ColumnType]s to native database types.
///
/// Static-only — cannot be instantiated.
final class TypeMapper {
  TypeMapper._();

  /// Returns the canonical PostgreSQL type name for [type].
  ///
  /// `length`, `precision`, and `scale` parameterize variable-width
  /// types. `elementType` is required for [ColumnType.array].
  static String toSqlType(
    ColumnType type, {
    int? length,
    int? precision,
    int? scale,
    ColumnType? elementType,
  }) => switch (type) {
    ColumnType.string => 'VARCHAR(${length ?? 255})',
    ColumnType.smallInteger => 'SMALLINT',
    ColumnType.integer => 'INTEGER',
    ColumnType.bigInteger => 'BIGINT',
    ColumnType.decimal => 'NUMERIC(${precision ?? 10},${scale ?? 2})',
    ColumnType.boolean => 'BOOLEAN',
    ColumnType.date => 'DATE',
    ColumnType.dateTime => 'TIMESTAMPTZ',
    ColumnType.uuid => 'UUID',
    ColumnType.json => 'JSON',
    ColumnType.jsonb => 'JSONB',
    ColumnType.text => 'TEXT',
    ColumnType.binary => 'BYTEA',
    ColumnType.doublePrecision => 'DOUBLE PRECISION',
    ColumnType.enumType => 'TEXT',
    ColumnType.tsvector => 'TSVECTOR',
    ColumnType.time => 'TIME',
    ColumnType.interval => 'INTERVAL',
    ColumnType.inet => 'INET',
    ColumnType.macaddr => 'MACADDR',
    ColumnType.point => 'POINT',
    ColumnType.line => 'LINE',
    ColumnType.box => 'BOX',
    ColumnType.money => 'MONEY',
    ColumnType.bit => 'BIT(${length ?? 1})',
    ColumnType.xml => 'XML',
    ColumnType.array => '${toSqlType(elementType ?? ColumnType.text)}[]',
  };

  /// Returns the canonical MongoDB BSON type tag for [type].
  static String toMongoType(ColumnType type) => switch (type) {
    ColumnType.string ||
    ColumnType.text ||
    ColumnType.uuid ||
    ColumnType.inet ||
    ColumnType.macaddr ||
    ColumnType.xml ||
    ColumnType.tsvector ||
    ColumnType.bit ||
    ColumnType.enumType => 'string',
    ColumnType.smallInteger || ColumnType.integer => 'int',
    ColumnType.bigInteger => 'long',
    ColumnType.decimal || ColumnType.money => 'decimal',
    ColumnType.doublePrecision => 'double',
    ColumnType.boolean => 'bool',
    ColumnType.date ||
    ColumnType.dateTime ||
    ColumnType.time ||
    ColumnType.interval => 'date',
    ColumnType.json ||
    ColumnType.jsonb ||
    ColumnType.point ||
    ColumnType.line ||
    ColumnType.box => 'object',
    ColumnType.array => 'array',
    ColumnType.binary => 'binData',
  };
}
