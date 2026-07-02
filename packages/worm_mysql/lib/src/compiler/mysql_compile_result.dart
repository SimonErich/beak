/// Immutable result of compiling a worm descriptor to MySQL SQL.
library;

/// Immutable container pairing a compiled SQL string with its
/// ordered positional parameter list.
///
/// Positional placeholders in [sql] use the MySQL `?` syntax and
/// correspond 1:1, left-to-right, to the entries in [parameters].
///
/// Returned by every `MysqlCompiler.compile*` method. Consumed by the
/// adapter to bind and execute a server-side prepared statement.
final class MysqlCompileResult {
  /// Creates a [MysqlCompileResult].
  const MysqlCompileResult({
    required this.sql,
    this.parameters = const <Object?>[],
  });

  /// The compiled SQL statement with `?` placeholders.
  final String sql;

  /// Positional parameter values aligned with the `?` placeholders in
  /// [sql], in left-to-right order.
  final List<Object?> parameters;
}
