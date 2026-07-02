/// Adapter that records (does not execute) descriptors for --pretend.
library;

import '../adapter/database_adapter.dart';
import '../query/aggregate_descriptor.dart';
import '../query/delete_descriptor.dart';
import '../query/insert_descriptor.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../query/update_descriptor.dart';

/// Drop-in [DatabaseAdapter] for `migrate --pretend`.
///
/// Every write or schema call is recorded as a compiled SQL-ish
/// string instead of executed. Reads return empty results. The
/// captured [statements] are printed by the CLI.
final class PretendAdapter extends DatabaseAdapter {
  /// Wraps [delegate] for `compileToString`. The delegate is never
  /// asked to execute anything; only its `compileToString` is used so
  /// the dry-run statements match the real adapter's syntax.
  PretendAdapter(this.delegate) : super(capabilities: delegate.capabilities);

  /// Real adapter used only for `compileToString` formatting.
  final DatabaseAdapter delegate;

  final List<String> _statements = <String>[];

  /// All captured statements, in execution order.
  List<String> get statements => List<String>.unmodifiable(_statements);

  void _record(Object descriptor) {
    _statements.add(delegate.compileToString(descriptor));
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) async {
    _record(d);
    return const <Map<String, Object?>>[];
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    _record(d);
    return null;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) async {
    _record(d);
    return const <String, Object?>{};
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) async {
    _record(d);
    return const <Map<String, Object?>>[];
  }

  @override
  Future<int> update(UpdateDescriptor d) async {
    _record(d);
    return 0;
  }

  @override
  Future<int> delete(DeleteDescriptor d) async {
    _record(d);
    return 0;
  }

  @override
  Future<int> count(AggregateDescriptor d) async {
    _record(d);
    return 0;
  }

  @override
  Future<num?> sum(AggregateDescriptor d) async {
    _record(d);
    return null;
  }

  @override
  Future<double?> avg(AggregateDescriptor d) async {
    _record(d);
    return null;
  }

  @override
  Future<Object?> min(AggregateDescriptor d) async {
    _record(d);
    return null;
  }

  @override
  Future<Object?> max(AggregateDescriptor d) async {
    _record(d);
    return null;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) async {
    _statements.add('RAW QUERY: $query');
    return const <Map<String, Object?>>[];
  }

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) async {
    _statements.add('RAW EXECUTE: $statement');
    return 0;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      action(this);

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    _record(d);
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() async =>
      const <String, List<String>>{};

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) {
    _record(d);
    return const Stream<Map<String, Object?>>.empty();
  }

  @override
  String compileToString(Object descriptor) =>
      delegate.compileToString(descriptor);
}
