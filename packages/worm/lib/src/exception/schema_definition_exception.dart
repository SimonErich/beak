/// Exception for a schema blueprint that cannot be compiled.
library;

import 'worm_exception.dart';

/// Thrown when a schema blueprint describes something incoherent — a
/// modification declared inside a `create`, a column dropped and re-added in
/// one `alter`, an `alter` with no steps.
///
/// Distinct from `UnsupportedOperationException`: that one signals a dialect
/// cannot express a well-formed request; this one signals the request is not
/// well formed on any dialect, so it is caught before a compiler ever sees it.
class SchemaDefinitionException extends WormException {
  /// Creates a [SchemaDefinitionException].
  const SchemaDefinitionException({
    required this.table,
    required this.operation,
    required String message,
  }) : super(message);

  /// The table the blueprint targets.
  final String table;

  /// The schema operation the blueprint was built for.
  final String operation;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'operation': operation,
  };
}
