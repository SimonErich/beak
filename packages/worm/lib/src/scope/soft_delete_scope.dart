/// Global scope that hides soft-deleted rows.
library;

import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_builder.dart';
import 'global_scope.dart';

/// Stable name of the soft-delete scope.
const String softDeleteScopeName = 'soft_deletes';

/// A [GlobalScope] that filters out rows whose
/// `deletedAt` column is non-null.
///
/// Models that opt in to soft deletes register an
/// instance of this scope. `QueryBuilder.withTrashed`
/// bypasses the scope by name.
final class SoftDeleteScope<T extends Model> extends GlobalScope<T> {
  /// Creates a [SoftDeleteScope].
  const SoftDeleteScope({this.column = 'deleted_at'});

  /// Column name used to flag a soft-deleted row.
  final String column;

  @override
  String get name => softDeleteScopeName;

  @override
  QueryBuilder<T> apply(QueryBuilder<T> builder) =>
      builder.where(Field<Object?>(column).isNull());
}
