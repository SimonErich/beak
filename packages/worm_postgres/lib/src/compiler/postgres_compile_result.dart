/// Immutable result of compiling a worm descriptor to Postgres SQL.
library;

/// Immutable container pairing a compiled SQL string with its
/// ordered positional parameter list.
///
/// Positional placeholders in [sql] use the Postgres `$1`, `$2`, …
/// syntax and correspond 1:1 to the entries in [parameters].
///
/// Returned by every `PostgresCompiler.compile*` method. Consumed
/// by the adapter to bind and execute the statement.
final class PostgresCompileResult {
  /// Creates a [PostgresCompileResult].
  const PostgresCompileResult({required this.sql, required this.parameters});

  /// The compiled SQL statement with `$1`-style placeholders.
  final String sql;

  /// Positional parameter values aligned with the placeholders in
  /// [sql]. The list order matches the `$N` indices.
  final List<Object?> parameters;
}
