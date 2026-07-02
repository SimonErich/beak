/// Database column type declarations.
library;

/// Supported database column types.
enum ColumnType {
  /// Variable-length character string.
  string,

  /// 16-bit signed integer.
  smallInteger,

  /// 32-bit signed integer.
  integer,

  /// 64-bit signed integer.
  bigInteger,

  /// Fixed-precision decimal number.
  decimal,

  /// Boolean true/false value.
  boolean,

  /// Calendar date without time.
  date,

  /// Date and time with timezone.
  dateTime,

  /// Universally unique identifier.
  uuid,

  /// JSON document (text storage).
  json,

  /// JSON document (binary storage).
  jsonb,

  /// Unlimited-length text.
  text,

  /// Raw binary data.
  binary,

  /// Double-precision floating point.
  doublePrecision,

  /// Database-level enum type.
  enumType,

  /// Full-text search vector.
  tsvector,

  /// Time without date.
  time,

  /// Time interval / duration.
  interval,

  /// IPv4 or IPv6 network address.
  inet,

  /// MAC address.
  macaddr,

  /// Geometric point.
  point,

  /// Geometric line segment.
  line,

  /// Axis-aligned rectangle.
  box,

  /// Monetary amount.
  money,

  /// Bit string of fixed length.
  bit,

  /// XML document.
  xml,

  /// Array of another column type.
  array,
}
