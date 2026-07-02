/// Immutable result of compiling a worm descriptor to a MongoDB
/// find-operation description.
library;

/// Describes a compiled MongoDB `find` operation.
///
/// Used by the Mongo adapter as a neutral intermediate form: the
/// compiler produces it from a `QueryDescriptor`, and the adapter
/// passes the fields into `mongo_dart`'s driver calls.
///
/// Every field is a plain Dart collection so the whole structure is
/// trivially JSON-serialisable for logging, golden tests, and
/// debugging.
final class MongoCompileResult {
  /// Creates a [MongoCompileResult].
  const MongoCompileResult({
    required this.collection,
    required this.filter,
    this.sort = const <String, int>{},
    this.projection,
    this.limit,
    this.skip,
  });

  /// The target MongoDB collection.
  final String collection;

  /// The BSON-compatible filter document. Empty `{}` means "match
  /// every document".
  final Map<String, Object?> filter;

  /// Sort specification: field → `1` (ascending) or `-1`
  /// (descending). Empty when no sort was requested.
  final Map<String, int> sort;

  /// Projection specification: field → `1` (include) or `0`
  /// (exclude). `null` means "return all fields".
  final Map<String, int>? projection;

  /// Maximum number of documents to return, or `null` for no limit.
  final int? limit;

  /// Number of documents to skip, or `null` for no offset.
  final int? skip;
}
