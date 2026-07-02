/// Abstract database adapter contract.
library;

import '../query/adapter_dialect.dart';
import '../query/aggregate_descriptor.dart';
import '../query/delete_descriptor.dart';
import '../query/insert_descriptor.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../query/update_descriptor.dart';
import 'adapter_capabilities.dart';

/// The contract every database adapter implements.
///
/// Adapters translate immutable [QueryDescriptor] and write
/// descriptors into native operations against their backing store.
///
/// Adapters implement the lifecycle, read, write, aggregation, raw
/// access, transaction, and schema operations below, plus the
/// [capabilities] getter, [stream], and the synchronous
/// [compileToString] debug method.
///
/// [aggregateGrouped] ships a concrete default (in-memory rollup) so
/// existing and third-party adapters need not implement it; SQL /
/// document adapters override it to push the `GROUP BY` into the
/// database.
///
/// Declared `abstract` (not `sealed`) so third-party packages may
/// implement it.
abstract class DatabaseAdapter {
  /// Base constructor accepting declared [capabilities].
  const DatabaseAdapter({
    AdapterCapabilities capabilities = const AdapterCapabilities(),
  }) : _capabilities = capabilities;

  final AdapterCapabilities _capabilities;

  /// Capability matrix for this adapter.
  ///
  /// Exposed as a getter so adapters whose capabilities depend on
  /// runtime state — e.g. replica-set detection after a Mongo
  /// connection opens — can override and compute the value at
  /// access time. Adapters that declare a static profile leave the
  /// default in place and pass the matrix in via `super(...)`.
  AdapterCapabilities get capabilities => _capabilities;

  /// Adapter family the runtime uses to gate
  /// `.sql()` / `.mongo()` query contexts. Defaults to
  /// [AdapterType.custom] so third-party adapters
  /// compile without opting into a bundled family;
  /// SQL and Mongo adapters override this getter to
  /// return [AdapterType.sql] and [AdapterType.mongodb]
  /// respectively.
  AdapterType get adapterType => AdapterType.custom;

  /// Establish the connection / initialize the backing store. Safe
  /// to call multiple times.
  Future<void> connect();

  /// Close connections and release all resources.
  Future<void> disconnect();

  /// Return all rows matching the descriptor.
  Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor);

  /// Return the first matching row, or `null`.
  Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor);

  /// Insert a single row and return it.
  Future<Map<String, Object?>> insert(InsertDescriptor descriptor);

  /// Insert multiple rows and return them.
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor descriptor,
  );

  /// Update matching rows and return the count.
  Future<int> update(UpdateDescriptor descriptor);

  /// Delete matching rows and return the count.
  Future<int> delete(DeleteDescriptor descriptor);

  /// Count matching rows.
  Future<int> count(AggregateDescriptor descriptor);

  /// Compute an aggregate (`count` or `sum`) per distinct
  /// [AggregateDescriptor.groupBy] value, returning one entry per
  /// group keyed by the group value.
  ///
  /// The eager loader uses this to roll up `withCount` / `withSum`
  /// across many parents in a single query. The base implementation
  /// fetches the (projected) matching rows and groups in memory; SQL /
  /// document adapters override it to push the `GROUP BY` into the
  /// database so only one row per group crosses the wire.
  Future<Map<Object?, num>> aggregateGrouped(
    AggregateDescriptor descriptor,
  ) async {
    final group = descriptor.groupBy;
    if (group == null) {
      return const <Object?, num>{};
    }
    final column = descriptor.column;
    final rows = await select(
      QueryDescriptor(
        table: descriptor.table,
        where: descriptor.where,
        columns: <String>[group, ?column],
      ),
    );
    final result = <Object?, num>{};
    for (final row in rows) {
      final key = row[group];
      if (descriptor.function == AggregateFunction.sum && column != null) {
        final value = row[column];
        if (value is num) result[key] = (result[key] ?? 0) + value;
      } else {
        result[key] = (result[key] ?? 0) + 1;
      }
    }
    return result;
  }

  /// Sum a numeric column over matching rows, or `null` when no
  /// rows match.
  Future<num?> sum(AggregateDescriptor descriptor);

  /// Average a numeric column over matching rows, or `null` when no
  /// rows match.
  Future<double?> avg(AggregateDescriptor descriptor);

  /// Minimum value of a column over matching rows.
  Future<Object?> min(AggregateDescriptor descriptor);

  /// Maximum value of a column over matching rows.
  Future<Object?> max(AggregateDescriptor descriptor);

  /// Execute a raw read query with parameters.
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  );

  /// Execute a raw write statement and return the number of affected
  /// rows.
  Future<int> rawExecute(String statement, List<Object?> parameters);

  /// Run [action] inside a transaction. The nested adapter passed to
  /// [action] represents the transactional context. Throwing inside
  /// [action] rolls the transaction back.
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action);

  /// Apply a schema DDL operation.
  Future<void> executeSchema(SchemaDescriptor descriptor);

  /// Introspect the live schema as a map of table name → declared
  /// columns. Adapters that do not persist column lists return an
  /// empty list for each known table.
  Future<Map<String, List<String>>> introspectSchema();

  /// Stream rows matching the descriptor with bounded memory.
  Stream<Map<String, Object?>> stream(QueryDescriptor descriptor);

  /// Compile a descriptor to a native string form for logging or
  /// debugging. Never executes the query.
  String compileToString(Object descriptor);

  // `explain` is provided by the `ExplainCapable` mixin from
  // `lib/src/logging/explain_runner.dart`. Adapters that support
  // EXPLAIN mix it in and override; consumers gate access via
  // `AdapterCapabilities.supportsExplain` + `is ExplainCapable`.
}
