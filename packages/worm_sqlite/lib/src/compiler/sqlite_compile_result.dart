/// Immutable result of compiling a worm descriptor to SQLite SQL.
library;

/// A compiled SQLite statement: the SQL text plus the ordered
/// positional parameter list bound to its `?` placeholders.
final class SqliteCompileResult {
  /// Creates a [SqliteCompileResult].
  const SqliteCompileResult({required this.sql, this.parameters = const []});

  /// The SQL text with `?` placeholders.
  final String sql;

  /// Positional parameters, in placeholder order.
  final List<Object?> parameters;
}
