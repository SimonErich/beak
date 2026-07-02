/// Data-mapper [Repository] base class.
library;

import '../adapter/database_adapter.dart';
import '../exception/model_not_found_exception.dart';
import '../query/delete_descriptor.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_descriptor.dart';
import 'active_record.dart';
import 'model.dart';

/// Opt-in data-mapper interface for projects that prefer to keep
/// persistence logic off the model itself.
///
/// Provides the same CRUD capability as the Active Record API on
/// [Model] (`save`, `delete`, `refresh`, `find`, `all`) but as an
/// independent class for projects that prefer the data-mapper
/// pattern.
///
/// Subclasses provide the [tableName], [hydrate] callback, and an
/// optional [primaryKeyColumn] override:
///
/// ```dart
/// class UserRepository extends Repository<User> {
///   const UserRepository(super.adapter);
///
///   @override
///   String get tableName => 'users';
///
///   @override
///   User hydrate(Map<String, Object?> row) => User.fromRow(row);
/// }
/// ```
abstract class Repository<T extends Model> {
  /// Creates a [Repository] bound to [adapter].
  const Repository(this.adapter);

  /// Database adapter used by every CRUD method.
  final DatabaseAdapter adapter;

  /// Database table the repository targets.
  String get tableName;

  /// Primary-key column name; defaults to `'id'`.
  String get primaryKeyColumn => 'id';

  /// Convert a raw row to a typed model.
  T hydrate(Map<String, Object?> row);

  /// Persist [model]. Equivalent to `model.save()`.
  Future<bool> save(T model) => ActiveRecord.save(model);

  /// Delete [model]. Equivalent to `model.delete()`.
  Future<bool> delete(T model) => ActiveRecord.delete(model);

  /// Refresh [model] from the database.
  Future<void> refresh(T model) => ActiveRecord.refresh(model);

  /// Look up by primary key, or `null` when no row matches.
  Future<T?> find(Object id) async {
    final row = await adapter.selectOne(
      QueryDescriptor(
        table: tableName,
        where: Field<Object?>(primaryKeyColumn).eq(id),
        limit: 1,
      ),
    );
    if (row == null) return null;
    return hydrate(row)..markPersisted();
  }

  /// Look up by primary key, or throw [ModelNotFoundException].
  Future<T> findOrFail(Object id) async {
    final model = await find(id);
    if (model == null) {
      throw ModelNotFoundException(
        model: '$T',
        id: id,
        message: 'No $T with id "$id" in table "$tableName"',
      );
    }
    return model;
  }

  /// Load every row in [tableName] as a list of [T].
  Future<List<T>> all() async {
    final rows = await adapter.select(QueryDescriptor(table: tableName));
    return <T>[for (final row in rows) hydrate(row)..markPersisted()];
  }

  /// Delete every row matching [id]. Returns the affected count.
  Future<int> deleteById(Object id) => adapter.delete(
    DeleteDescriptor(
      table: tableName,
      where: Field<Object?>(primaryKeyColumn).eq(id),
    ),
  );
}
