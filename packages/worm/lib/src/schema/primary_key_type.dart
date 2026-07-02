/// Primary key generation strategies.
library;

/// Strategy for generating primary key values.
enum PrimaryKeyType {
  /// UUID-based primary key.
  uuid,

  /// Auto-incrementing integer primary key.
  integer,
}
