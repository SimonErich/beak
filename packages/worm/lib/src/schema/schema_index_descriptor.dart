/// Schema descriptor for index creation across adapters.
library;

import '../query/schema_descriptor.dart';

/// Immutable description of an index-creation request.
///
/// Adapters consume this through `DatabaseAdapter.executeSchema`
/// alongside the existing table-level `SchemaDescriptor` family —
/// it extends `SchemaDescriptor` so it flows through the same
/// dispatch with `SchemaOperation.createIndex`.
///
/// SQL adapters compile the descriptor into a `CREATE UNIQUE
/// INDEX` statement; MongoDB-style adapters translate it into a
/// `db.collection.createIndex` call.
final class SchemaIndexDescriptor extends SchemaDescriptor {
  /// Creates a [SchemaIndexDescriptor].
  const SchemaIndexDescriptor({
    required this.collection,
    required this.field,
    this.unique = false,
  }) : super(operation: SchemaOperation.createIndex, table: collection);

  /// The target collection / table the index lives on.
  final String collection;

  /// The field / column the index covers.
  final String field;

  /// Whether the index enforces a uniqueness constraint.
  final bool unique;
}
