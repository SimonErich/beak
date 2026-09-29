/// A column as the database describes it.
final class IntrospectedColumn {
  /// Creates a described column.
  const IntrospectedColumn({
    required this.name,
    required this.dataType,
    required this.isNullable,
    this.maxLength,
    this.numericPrecision,
    this.numericScale,
    this.hasDefault = false,
    this.enumTypeName,
    this.enumValues = const [],
    this.isIndexed = false,
    this.isUnique = false,
  });

  /// Column name, as stored.
  final String name;

  /// `information_schema` data type, lower-case.
  final String dataType;

  /// Whether the column accepts null.
  final bool isNullable;

  /// Declared character limit, for a varchar.
  final int? maxLength;

  /// Total stored digits, for a numeric column.
  final int? numericPrecision;

  /// Fraction digits, for a numeric column.
  final int? numericScale;

  /// Whether the column has a default, which makes it effectively optional
  /// on insert even when it is `NOT NULL`.
  final bool hasDefault;

  /// The Postgres enum type backing this column, when it is one.
  final String? enumTypeName;

  /// The enum's labels, in declaration order.
  final List<String> enumValues;

  /// Whether an index covers this column.
  ///
  /// An index a database already has is a decision somebody made about how it
  /// is queried. Reading it back is what keeps `beak introspect` from handing
  /// you a schema that looks right and runs slowly.
  final bool isIndexed;

  /// Whether that index makes the column's values distinct.
  final bool isUnique;
}

/// A foreign key as the database describes it.
final class IntrospectedForeignKey {
  /// Creates a described foreign key.
  const IntrospectedForeignKey({
    required this.column,
    required this.referencedTable,
  });

  /// The column holding the reference.
  final String column;

  /// The table it points at.
  final String referencedTable;
}

/// A table as the database describes it.
final class IntrospectedTable {
  /// Creates a described table.
  const IntrospectedTable({
    required this.name,
    required this.columns,
    this.foreignKeys = const [],
    this.primaryKey = 'id',
  });

  /// Table name.
  final String name;

  /// Columns, in ordinal order.
  final List<IntrospectedColumn> columns;

  /// Foreign keys declared on this table.
  final List<IntrospectedForeignKey> foreignKeys;

  /// The primary-key column.
  final String primaryKey;

  /// Whether the table carries a soft-delete marker.
  bool get softDeletes => columns.any((column) => column.name == 'deleted_at');

  /// Whether the table carries created/updated stamps.
  bool get timestamps =>
      columns.any((column) => column.name == 'created_at') &&
      columns.any((column) => column.name == 'updated_at');

  /// Whether this table is a pure join table: nothing but a key pair, and
  /// optionally a surrogate id and stamps.
  ///
  /// Such a table is a *relationship*, not a resource — surfacing it as its
  /// own admin page would be noise.
  bool get isPivot {
    if (foreignKeys.length != 2) {
      return false;
    }
    const ignorable = {'id', 'created_at', 'updated_at', 'deleted_at'};
    final keys = {for (final fk in foreignKeys) fk.column};
    return columns.every(
      (column) => keys.contains(column.name) || ignorable.contains(column.name),
    );
  }
}

/// The bookkeeping tables of other migration tools.
///
/// Finding one means another tool owns this database's schema, and `beak
/// introspect` defaults to leaving it that way rather than adopting it.
const Set<String> foreignMigrationTables = {
  'schema_migrations',
  '_prisma_migrations',
  'django_migrations',
  'flyway_schema_history',
  'alembic_version',
  '__EFMigrationsHistory',
  'knex_migrations',
};

/// The table Serverpod keeps its migration history in.
const String serverpodMigrationsTable = 'serverpod_migrations';

/// The prefix of every table a Serverpod server creates for itself.
const String serverpodTablePrefix = 'serverpod_';

/// Tables Beak never surfaces: migration bookkeeping written by frameworks,
/// Beak's own included.
///
/// `beak migrate` creates the receipts and the outbox in every database it
/// touches, so introspecting one it has already migrated would otherwise
/// write a resource for each.
const Set<String> introspectionSkipTables = {
  'migrations',
  'worm_migrations',
  '_beak_commit_receipts',
  '_beak_outbox',
  'ar_internal_metadata',
  'knex_migrations_lock',
  serverpodMigrationsTable,
  ...foreignMigrationTables,
};

/// Column names that almost always hold a secret.
///
/// Omitted from generated schemas with a warning rather than rendered in a
/// table: an admin panel that displays password hashes is a liability, and
/// silently including them would be the worst possible default.
const Set<String> introspectionSecretColumns = {
  'password',
  'password_hash',
  'encrypted_password',
  'secret',
  'token',
  'api_key',
  'access_token',
  'refresh_token',
  'private_key',
};
