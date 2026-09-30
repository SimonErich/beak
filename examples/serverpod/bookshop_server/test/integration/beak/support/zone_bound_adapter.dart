/// Test support for the contract suites: the request zone and throwaway DDL.
library;

import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart' show PostgresCompiler;

/// What the contract suites may exercise. The production adapter leaves
/// schema changes to Serverpod's migrations (`serverpodSessionAdapterCapabilities`);
/// the suites create throwaway tables, which [ZoneBoundAdapter] allows in tests
/// only.
const AdapterCapabilities contractCapabilities = AdapterCapabilities(
  supportsTransactions: true,
  supportsSavepoints: true,
  supportsStreaming: true,
  supportsRawQuery: true,
  supportsReturning: true,
  supportsJoins: true,
  supportsAggregations: true,
  supportsSchemaIntrospection: true,
  supportsColumnAlterations: true,
  supportsExplain: true,
);

/// Runs every call of a [ServerpodSessionAdapter] inside
/// [BeakServerpod.runInSession], and adds test-only DDL.
///
/// The contract suites call the adapter from test bodies, which the test
/// runner owns, so the zone cannot wrap them. This wrapper is the zone the
/// engine's `dispatch` sets in production, re-entered per call; the wrapped
/// adapter still finds its session only through the zone. DDL goes through
/// the adapter's own `rawExecute`.
final class ZoneBoundAdapter extends DatabaseAdapter with ExplainCapable {
  /// Wraps [inner], entering [session]'s zone for each call.
  ZoneBoundAdapter(this.session, this.inner)
    : super(capabilities: contractCapabilities);

  /// The session the zone carries.
  final Session session;

  /// The zone-reading adapter under test.
  final ServerpodSessionAdapter inner;

  R _zoned<R>(R Function() body) => BeakServerpod.runInSession(session, body);

  @override
  Future<void> connect() => _zoned(inner.connect);

  @override
  Future<void> disconnect() => _zoned(inner.disconnect);

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _zoned(() => inner.select(d));

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _zoned(() => inner.selectOne(d));

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) =>
      _zoned(() => inner.insert(d));

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _zoned(() => inner.insertMany(d));

  @override
  Future<int> update(UpdateDescriptor d) => _zoned(() => inner.update(d));

  @override
  Future<int> delete(DeleteDescriptor d) => _zoned(() => inner.delete(d));

  @override
  Future<int> count(AggregateDescriptor d) => _zoned(() => inner.count(d));

  @override
  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor d) =>
      _zoned(() => inner.aggregateGrouped(d));

  @override
  Future<num?> sum(AggregateDescriptor d) => _zoned(() => inner.sum(d));

  @override
  Future<double?> avg(AggregateDescriptor d) => _zoned(() => inner.avg(d));

  @override
  Future<Object?> min(AggregateDescriptor d) => _zoned(() => inner.min(d));

  @override
  Future<Object?> max(AggregateDescriptor d) => _zoned(() => inner.max(d));

  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _zoned(() => inner.rawQuery(q, p));

  @override
  Future<int> rawExecute(String s, List<Object?> p) =>
      _zoned(() => inner.rawExecute(s, p));

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _zoned(() => inner.transaction(action));

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    // One descriptor can be several statements (a table plus its indexes);
    // the extended protocol takes one at a time.
    for (final compiled in const PostgresCompiler().compileDdl(d)) {
      await rawExecute(compiled.sql, compiled.parameters);
    }
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() async {
    final rows = await rawQuery(
      'SELECT table_name, column_name FROM information_schema.columns '
      'WHERE table_schema = current_schema() '
      'ORDER BY table_name, ordinal_position',
      const [],
    );
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      if (row case {
        'table_name': final String table,
        'column_name': final String column,
      }) {
        grouped.putIfAbsent(table, () => []).add(column);
      }
    }
    return grouped;
  }

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) =>
      _zoned(() => inner.stream(d));

  @override
  String compileToString(Object d) => inner.compileToString(d);

  @override
  Future<ExplainResult> explain(QueryDescriptor d) =>
      _zoned(() => inner.explain(d));
}
