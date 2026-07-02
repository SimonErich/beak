/// Index definition used by the schema builder.
library;

/// Kinds of indexes supported by [IndexDefinition].
enum IndexKind {
  /// Standard B-tree index.
  btree,

  /// Generalized-search-tree (`GIN`) index.
  gin,

  /// Generalized-search-tree (`GIST`) index.
  gist,

  /// Hash index.
  hash,
}

/// An index definition produced by the schema builder.
final class IndexDefinition {
  /// Creates an [IndexDefinition].
  const IndexDefinition({
    required this.name,
    required this.columns,
    this.unique = false,
    this.kind = IndexKind.btree,
    this.partialWhere,
  });

  /// Index name.
  final String name;

  /// Columns covered by the index.
  final List<String> columns;

  /// Whether this index enforces uniqueness.
  final bool unique;

  /// The index storage strategy.
  final IndexKind kind;

  /// Optional `WHERE` clause for partial indexes.
  final String? partialWhere;

  /// Serializes the index to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'columns': columns,
    if (unique) 'unique': true,
    'kind': kind.name,
    if (partialWhere != null) 'where': partialWhere,
  };
}
