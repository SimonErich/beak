/// Adapter wrapper that records every query and enforces strictness.
library;

import '../adapter/database_adapter.dart';
import '../config/strictness_config.dart';
import '../exception/dangerous_query_exception.dart';
import '../query/aggregate_descriptor.dart';
import '../query/delete_descriptor.dart';
import '../query/insert_descriptor.dart';
import '../query/operator.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import '../query/schema_descriptor.dart';
import '../query/update_descriptor.dart';
import 'explain_runner.dart';
import 'n_plus_one_detector.dart';
import 'query_log.dart';
import 'query_logger.dart';

/// Wraps a [DatabaseAdapter] to time every call, emit [QueryLog]
/// records, detect slow queries, and warn on N+1 or missing-index
/// patterns when the corresponding strictness flag is set.
final class LoggingAdapter extends DatabaseAdapter {
  /// Creates a [LoggingAdapter] around [inner].
  LoggingAdapter({
    required this.inner,
    required this.logger,
    required this.strictness,
    this.adapterName = 'DatabaseAdapter',
    NPlusOneDetector? detector,
    MissingIndexWarner? missingIndexWarner,
  }) : _detector = detector ?? NPlusOneDetector(),
       _missingIndexWarner = missingIndexWarner ?? const MissingIndexWarner(),
       super(capabilities: inner.capabilities);

  /// Wrapped adapter that does the actual work.
  final DatabaseAdapter inner;

  /// Sink for log entries.
  final QueryLogger logger;

  /// Strictness flags to enforce.
  final StrictnessConfig strictness;

  /// Stable label for the wrapped adapter (used in log output).
  final String adapterName;

  final NPlusOneDetector _detector;
  final MissingIndexWarner _missingIndexWarner;

  @override
  Future<void> connect() => inner.connect();

  @override
  Future<void> disconnect() => inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final rows = await inner.select(descriptor);
    sw.stop();
    final entry = _entry(descriptor, sw.elapsed, rows.length);
    _emit(entry);
    _checkNPlusOne(descriptor, rows.length);
    await _checkMissingIndex(descriptor);
    return rows;
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final row = await inner.selectOne(descriptor);
    sw.stop();
    final rowCount = row == null ? 0 : 1;
    final entry = _entry(descriptor, sw.elapsed, rowCount);
    _emit(entry);
    _checkNPlusOne(descriptor, rowCount);
    await _checkMissingIndex(descriptor);
    return row;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final row = await inner.insert(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 1));
    return row;
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor descriptor,
  ) async {
    final sw = Stopwatch()..start();
    final rows = await inner.insertMany(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, rows.length));
    return rows;
  }

  @override
  Future<int> update(UpdateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final affected = await inner.update(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, affected));
    return affected;
  }

  @override
  Future<int> delete(DeleteDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final affected = await inner.delete(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, affected));
    return affected;
  }

  @override
  Future<int> count(AggregateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final result = await inner.count(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, result));
    return result;
  }

  @override
  Future<num?> sum(AggregateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final result = await inner.sum(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 1));
    return result;
  }

  @override
  Future<double?> avg(AggregateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final result = await inner.avg(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 1));
    return result;
  }

  @override
  Future<Object?> min(AggregateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final result = await inner.min(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 1));
    return result;
  }

  @override
  Future<Object?> max(AggregateDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    final result = await inner.max(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 1));
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) async {
    final sw = Stopwatch()..start();
    final rows = await inner.rawQuery(query, parameters);
    sw.stop();
    _emit(
      QueryLog(
        statement: query,
        parameters: parameters,
        duration: sw.elapsed,
        rowCount: rows.length,
        adapter: adapterName,
      ),
    );
    return rows;
  }

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) async {
    final sw = Stopwatch()..start();
    final affected = await inner.rawExecute(statement, parameters);
    sw.stop();
    _emit(
      QueryLog(
        statement: statement,
        parameters: parameters,
        duration: sw.elapsed,
        rowCount: affected,
        adapter: adapterName,
      ),
    );
    return affected;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      inner.transaction(
        (tx) => action(
          LoggingAdapter(
            inner: tx,
            logger: logger,
            strictness: strictness,
            adapterName: adapterName,
            detector: _detector,
            missingIndexWarner: _missingIndexWarner,
          ),
        ),
      );

  @override
  Future<void> executeSchema(SchemaDescriptor descriptor) async {
    final sw = Stopwatch()..start();
    await inner.executeSchema(descriptor);
    sw.stop();
    _emit(_entry(descriptor, sw.elapsed, 0));
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor descriptor) =>
      inner.stream(descriptor);

  @override
  String compileToString(Object descriptor) =>
      inner.compileToString(descriptor);

  void _emit(QueryLog entry) {
    logger.log(entry);
    if (entry.duration >= strictness.slowQueryThreshold) {
      logger.slowQuery(entry, strictness.slowQueryThreshold);
    }
  }

  void _checkNPlusOne(QueryDescriptor d, int rowCount) {
    // Either flag arms the detector — `throwOnN1Queries` alone is
    // enough because callers may want the strict gate without
    // double-emitting a `[WARNING]` line first.
    if (!strictness.warnOnN1Queries && !strictness.throwOnN1Queries) {
      return;
    }
    if (!_looksLikeSingleRowLookup(d, rowCount)) return;
    _detector.recordQuery(d.table);
    if (!_detector.shouldWarn(d.table)) return;
    _detector.resetTable(d.table);
    final message =
        'N+1: ${_detector.threshold}+ same-table queries on "${d.table}" '
        'within ${_detector.window.inMilliseconds}ms. Consider eager '
        'loading.';
    if (strictness.throwOnN1Queries) {
      // Throw without first emitting a warning — the exception
      // itself carries the diagnostic, and a double-emission would
      // pollute log assertions in tests that only configure strict
      // mode.
      throw DangerousQueryException(table: d.table, message: message);
    }
    logger.logWarning(message);
  }

  Future<void> _checkMissingIndex(QueryDescriptor d) async {
    if (!strictness.warnOnMissingIndex) return;
    await _missingIndexWarner.checkAfterQuery(
      descriptor: d,
      capabilities: inner.capabilities,
      adapter: inner,
      logger: logger,
    );
  }

  bool _looksLikeSingleRowLookup(QueryDescriptor d, int rowCount) {
    if (d.limit == 1) return true;
    if (rowCount > 1) return false;
    final where = d.where;
    if (where == null) return false;
    return _treeFields(
      where,
    ).any((String name) => name == 'id' || name.endsWith('_id'));
  }

  static List<String> _treeFields(PredicateTree tree) => switch (tree) {
    LeafNode(:final Predicate predicate) => <String>[predicate.fieldName],
    AndNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._treeFields(left),
      ..._treeFields(right),
    ],
    OrNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._treeFields(left),
      ..._treeFields(right),
    ],
    NotNode(:final PredicateTree child) => _treeFields(child),
    GroupNode(:final PredicateTree child) => _treeFields(child),
    ColumnNode(:final String leftField, :final String rightField) => <String>[
      leftField,
      rightField,
    ],
    ExistsNode() => const <String>[],
    RawNode() => const <String>[],
  };

  QueryLog _entry(Object descriptor, Duration duration, int rowCount) {
    final statement = inner.compileToString(descriptor);
    return QueryLog(
      statement: statement,
      parameters: _parametersOf(descriptor),
      duration: duration,
      rowCount: rowCount,
      adapter: adapterName,
      table: _tableOf(descriptor),
    );
  }

  String? _tableOf(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => d.table,
    final InsertDescriptor d => d.table,
    final InsertManyDescriptor d => d.table,
    final UpdateDescriptor d => d.table,
    final DeleteDescriptor d => d.table,
    final AggregateDescriptor d => d.table,
    final SchemaDescriptor d => d.table,
    _ => null,
  };

  List<Object?> _parametersOf(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => _treeParams(d.where),
    final InsertDescriptor d => d.values.values.toList(),
    final InsertManyDescriptor d => <Object?>[
      for (final row in d.rows) ...row.values,
    ],
    final UpdateDescriptor d => <Object?>[
      ...d.values.values,
      ..._treeParams(d.where),
    ],
    final DeleteDescriptor d => _treeParams(d.where),
    final AggregateDescriptor d => _treeParams(d.where),
    _ => const <Object?>[],
  };

  static List<Object?> _treeParams(PredicateTree? tree) {
    if (tree == null) return const <Object?>[];
    final out = <Object?>[];
    void walk(PredicateTree node) {
      switch (node) {
        case LeafNode(:final Predicate predicate):
          if (predicate.operator == Operator.isNull ||
              predicate.operator == Operator.isNotNull) {
            return;
          }
          final value = predicate.value;
          if (value is List<Object?>) {
            out.addAll(value);
          } else if (value is (Object?, Object?)) {
            out
              ..add(value.$1)
              ..add(value.$2);
          } else {
            out.add(value);
          }
        case AndNode(:final PredicateTree left, :final PredicateTree right):
          walk(left);
          walk(right);
        case OrNode(:final PredicateTree left, :final PredicateTree right):
          walk(left);
          walk(right);
        case NotNode(:final PredicateTree child):
          walk(child);
        case GroupNode(:final PredicateTree child):
          walk(child);
        case ColumnNode():
          break;
        case ExistsNode():
          break;
        case RawNode(:final List<Object?> parameters):
          out.addAll(parameters);
      }
    }

    walk(tree);
    return out;
  }
}
