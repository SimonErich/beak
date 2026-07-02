import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/logging/explain_runner.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';

/// Delegating wrapper around [InMemoryAdapter] so tests can override
/// individual methods without subclassing the final adapter.
base class DelegatingAdapter extends DatabaseAdapter {
  DelegatingAdapter(this._inner) : super(capabilities: _inner.capabilities);

  factory DelegatingAdapter.fresh() => DelegatingAdapter(InMemoryAdapter());

  final InMemoryAdapter _inner;

  /// Exposed for fixture helpers.
  InMemoryAdapter get inner => _inner;

  @override
  AdapterCapabilities get capabilities => _inner.capabilities;
  @override
  Future<void> connect() => _inner.connect();
  @override
  Future<void> disconnect() => _inner.disconnect();
  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _inner.select(d);
  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _inner.selectOne(d);
  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _inner.insert(d);
  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _inner.insertMany(d);
  @override
  Future<int> update(UpdateDescriptor d) => _inner.update(d);
  @override
  Future<int> delete(DeleteDescriptor d) => _inner.delete(d);
  @override
  Future<int> count(AggregateDescriptor d) => _inner.count(d);
  @override
  Future<num?> sum(AggregateDescriptor d) => _inner.sum(d);
  @override
  Future<double?> avg(AggregateDescriptor d) => _inner.avg(d);
  @override
  Future<Object?> min(AggregateDescriptor d) => _inner.min(d);
  @override
  Future<Object?> max(AggregateDescriptor d) => _inner.max(d);
  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _inner.rawQuery(q, p);
  @override
  Future<int> rawExecute(String s, List<Object?> p) => _inner.rawExecute(s, p);
  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _inner.transaction(action);
  @override
  Future<void> executeSchema(SchemaDescriptor d) => _inner.executeSchema(d);
  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();
  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _inner.stream(d);
  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}

/// Delegating adapter whose [select] awaits long enough to trip the
/// slow-query threshold.
final class SlowAdapter extends DelegatingAdapter {
  SlowAdapter() : super(InMemoryAdapter());

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.select(d);
  }
}

/// Delegating adapter that exposes a stub EXPLAIN plan.
final class ExplainAdapter extends DelegatingAdapter with ExplainCapable {
  ExplainAdapter({required this.indexed}) : super(InMemoryAdapter());

  final Set<String> indexed;

  @override
  Future<ExplainResult> explain(QueryDescriptor d) async {
    final hit = _collectFields(d.where).any(indexed.contains);
    return ExplainResult(
      raw: hit ? 'Index Scan on ${d.table}' : 'Seq Scan on ${d.table}',
      usesIndex: hit,
      scannedTables: hit ? const <String>[] : <String>[d.table],
    );
  }

  static List<String> _collectFields(PredicateTree? tree) => switch (tree) {
    null => const <String>[],
    LeafNode(:final Predicate predicate) => <String>[predicate.fieldName],
    AndNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._collectFields(left),
      ..._collectFields(right),
    ],
    OrNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._collectFields(left),
      ..._collectFields(right),
    ],
    NotNode(:final PredicateTree child) => _collectFields(child),
    GroupNode(:final PredicateTree child) => _collectFields(child),
    ColumnNode(:final String leftField, :final String rightField) => <String>[
      leftField,
      rightField,
    ],
    ExistsNode() => const <String>[],
    RawNode() => const <String>[],
  };
}

/// Delegating adapter that mixes in [ExplainCapable] but reports
/// `supportsExplain = false`. Used to verify the missing-index
/// warner stays silent when the capability flag is off.
final class CapabilityFreeExplainAdapter extends DelegatingAdapter
    with ExplainCapable {
  CapabilityFreeExplainAdapter()
    : super(
        InMemoryAdapter(
          capabilities: const AdapterCapabilities(supportsTransactions: true),
        ),
      );

  @override
  Future<ExplainResult> explain(QueryDescriptor d) async =>
      const ExplainResult(usesIndex: false, raw: 'Seq Scan');
}
