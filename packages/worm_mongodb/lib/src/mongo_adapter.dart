/// Full `DatabaseAdapter` implementation backed by MongoDB.
library;

import 'dart:convert';

import 'package:worm/worm.dart';

import 'compiler/mongo_compile_result.dart';
import 'compiler/mongo_filter_compiler.dart';
import 'connection/mongo_connection.dart';
import 'mongo_error_mapper.dart';

/// MongoDB-backed [DatabaseAdapter].
///
/// Compiles every worm descriptor with [MongoFilterCompiler] and
/// dispatches it through the `mongo_dart` driver. Aliases worm's
/// canonical primary-key column `id` to MongoDB's `_id` on every
/// read and write so user-level code stays database-agnostic.
///
/// [capabilities] reports `supportsTransactions: false`: the
/// `mongo_dart` driver exposes no client-session / transaction API,
/// so multi-document transactions (atomic commit, rollback) cannot be
/// honoured even against a replica set. [transaction] therefore throws
/// [TransactionException] rather than silently running writes without
/// isolation.
final class MongoAdapter extends DatabaseAdapter with ExplainCapable {
  /// Creates an adapter using [connection].
  MongoAdapter({
    required MongoConnection connection,
    MongoFilterCompiler compiler = const MongoFilterCompiler(),
  }) : _connection = connection,
       _compiler = compiler,
       super();

  static const AdapterCapabilities _capabilities = AdapterCapabilities(
    // The mongo_dart driver has no session/transaction primitives, so
    // the adapter cannot deliver atomic multi-document transactions.
    supportsTransactions: false,
    supportsSavepoints: false,
    supportsStreaming: true,
    supportsRawQuery: false,
    // insert() and insertMany() both populate the stored document
    // via _projectReturning(), so the adapter materially supports
    // RETURNING-style result projection even though MongoDB has no
    // SQL RETURNING clause. The contract test correspondingly
    // declares supportsReturning: true.
    supportsReturning: true,
    supportsJoins: false,
    supportsPreparedStatements: false,
    supportsAggregations: true,
    supportsSchemaIntrospection: true,
    supportsExplain: true,
  );

  final MongoConnection _connection;
  final MongoFilterCompiler _compiler;

  @override
  AdapterCapabilities get capabilities => _capabilities;

  /// The driver-level connection used by this adapter.
  MongoConnection get connection => _connection;

  /// The compiler used for descriptor-to-Mongo translation.
  MongoFilterCompiler get compiler => _compiler;

  @override
  Future<void> connect() => _connection.open();

  @override
  Future<void> disconnect() => _connection.close();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    final compiled = _compiler.compileQuery(d);
    return MongoErrorMapper.wrap(() async {
      final cursor = _connection.db
          .collection(compiled.collection)
          .modernFind(
            filter: compiled.filter.isEmpty ? null : compiled.filter,
            sort: _maybeObjectMap(compiled.sort),
            projection: compiled.projection == null
                ? null
                : _toObjectMap(compiled.projection!),
            skip: compiled.skip,
            limit: compiled.limit,
          );
      return <Map<String, Object?>>[
        await for (final row in cursor) _aliasFromMongo(row),
      ];
    }, table: compiled.collection);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) {
    final compiled = _compiler.compileQuery(d.copyWith(limit: 1));
    return MongoErrorMapper.wrap(() async {
      final row = await _connection.db
          .collection(compiled.collection)
          .modernFindOne(
            filter: compiled.filter.isEmpty ? null : compiled.filter,
            sort: _maybeObjectMap(compiled.sort),
            projection: compiled.projection == null
                ? null
                : _toObjectMap(compiled.projection!),
            skip: compiled.skip,
          );
      return row == null ? null : _aliasFromMongo(row);
    }, table: compiled.collection);
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) =>
      MongoErrorMapper.wrap(() async {
        final document = _aliasToMongo(d.values);
        final result = await _connection.db
            .collection(d.table)
            .insertOne(document);
        if (result.hasWriteErrors) {
          throw MongoErrorMapper.fromWriteCommandError(
            code: result.writeError?.code,
            errmsg: result.writeError?.errmsg,
            table: d.table,
          );
        }
        final stored = result.document ?? document;
        return _projectReturning(_aliasFromMongoDoc(stored), d.returning);
      }, table: d.table);

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      MongoErrorMapper.wrap(() async {
        if (d.rows.isEmpty) return const <Map<String, Object?>>[];
        final documents = <Map<String, dynamic>>[
          for (final row in d.rows) _aliasToMongo(row),
        ];
        final result = await _connection.db
            .collection(d.table)
            .insertMany(documents);
        if (result.hasWriteErrors) {
          final first = result.writeErrors.first;
          throw MongoErrorMapper.fromWriteCommandError(
            code: first.code,
            errmsg: first.errmsg,
            table: d.table,
          );
        }
        return <Map<String, Object?>>[
          for (final doc in documents)
            _projectReturning(_aliasFromMongo(doc), d.returning),
        ];
      }, table: d.table);

  @override
  Future<int> update(UpdateDescriptor d) => MongoErrorMapper.wrap(() async {
    final filter = _compiler.compileFilter(d.where);
    final patch = <String, Object?>{r'$set': _aliasToMongo(d.values)};
    final result = await _connection.db
        .collection(d.table)
        .updateMany(filter, patch);
    return result.nModified;
  }, table: d.table);

  @override
  Future<int> delete(DeleteDescriptor d) => MongoErrorMapper.wrap(() async {
    final filter = _compiler.compileFilter(d.where);
    final result = await _connection.db.collection(d.table).deleteMany(filter);
    return result.nRemoved;
  }, table: d.table);

  @override
  Future<int> count(AggregateDescriptor d) => MongoErrorMapper.wrap(() async {
    final filter = _compiler.compileFilter(d.where);
    return _connection.db.collection(d.table).count(filter);
  }, table: d.table);

  @override
  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor descriptor) {
    final group = descriptor.groupBy;
    if (group == null) return super.aggregateGrouped(descriptor);
    return MongoErrorMapper.wrap(() async {
      final filter = _compiler.compileFilter(descriptor.where);
      final groupField = group == 'id' ? '_id' : group;
      final isSum =
          descriptor.function == AggregateFunction.sum &&
          descriptor.column != null;
      final accumulator = isSum
          ? <String, Object?>{r'$sum': '\$${descriptor.column}'}
          : const <String, Object?>{r'$sum': 1};
      // Top-level stages must be `Map<String, Object>` for
      // `modernAggregate`; nested `$group` body stays `Object?`-valued.
      final pipeline = <Map<String, Object>>[
        if (filter.isNotEmpty) <String, Object>{r'$match': filter},
        <String, Object>{
          r'$group': <String, Object?>{
            '_id': '\$$groupField',
            'value': accumulator,
          },
        },
      ];
      final docs = await _connection.db
          .collection(descriptor.table)
          .modernAggregate(pipeline)
          .toList();
      final result = <Object?, num>{};
      for (final doc in docs) {
        final value = doc['value'];
        if (value is num) result[doc['_id']] = value;
      }
      return result;
    }, table: descriptor.table);
  }

  @override
  Future<num?> sum(AggregateDescriptor d) async {
    final value = await _scalarAggregate(d, r'$sum');
    if (value is num) return value;
    return null;
  }

  @override
  Future<double?> avg(AggregateDescriptor d) async {
    final value = await _scalarAggregate(d, r'$avg');
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  Future<Object?> min(AggregateDescriptor d) => _scalarAggregate(d, r'$min');

  @override
  Future<Object?> max(AggregateDescriptor d) => _scalarAggregate(d, r'$max');

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) {
    throw const AdapterMismatchException(
      expectedAdapter: 'PostgresAdapter',
      actualAdapter: 'MongoAdapter',
      message:
          'MongoAdapter does not support raw SQL queries — '
          'use aggregate(), find(), or a typed worm descriptor.',
    );
  }

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) {
    throw const AdapterMismatchException(
      expectedAdapter: 'PostgresAdapter',
      actualAdapter: 'MongoAdapter',
      message:
          'MongoAdapter does not support raw SQL execute — '
          'use rawCommand or a typed worm descriptor.',
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) {
    throw const TransactionException(
      message:
          'MongoAdapter does not support transactions: the mongo_dart '
          'driver exposes no client-session / transaction API, so atomic '
          'commit and rollback cannot be guaranteed. Perform writes '
          'individually, or use a driver/adapter that supports MongoDB '
          'multi-document transactions.',
    );
  }

  @override
  Future<void> executeSchema(SchemaDescriptor d) =>
      MongoErrorMapper.wrap(() async {
        if (d is SchemaIndexDescriptor) {
          await _connection.db
              .collection(d.collection)
              .createIndex(key: d.field, unique: d.unique);
          return;
        }
        switch (d.operation) {
          case SchemaOperation.create:
            await _createCollection(d.table, ifNotExists: d.ifNotExists);
          case SchemaOperation.drop:
            await _dropCollection(d.table, ifExists: d.ifExists);
          case SchemaOperation.truncate:
            await _connection.db
                .collection(d.table)
                .deleteMany(const <String, Object?>{});
          case SchemaOperation.alter:
            throw const QueryException(
              query: '',
              message:
                  'MongoAdapter.executeSchema does not support '
                  'SchemaOperation.alter — Mongo collections are '
                  'schemaless.',
            );
          case SchemaOperation.createIndex:
            throw const QueryException(
              query: '',
              message:
                  'executeSchema(SchemaOperation.createIndex) requires '
                  'a SchemaIndexDescriptor',
            );
        }
      }, table: d.table);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      MongoErrorMapper.wrap(() async {
        final names = await _connection.db.getCollectionNames();
        return <String, List<String>>{
          for (final name in names) ?name: const <String>[],
        };
      });

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) async* {
    final compiled = _compiler.compileQuery(d);
    try {
      final cursor = _connection.db
          .collection(compiled.collection)
          .modernFind(
            filter: compiled.filter.isEmpty ? null : compiled.filter,
            sort: _maybeObjectMap(compiled.sort),
            projection: compiled.projection == null
                ? null
                : _toObjectMap(compiled.projection!),
            skip: compiled.skip,
            limit: compiled.limit,
          );
      await for (final row in cursor) {
        yield _aliasFromMongo(row);
      }
    } on WormException {
      rethrow;
    } catch (error) {
      throw MongoErrorMapper.map(error, table: compiled.collection);
    }
  }

  @override
  String compileToString(Object descriptor) =>
      _compiler.compileToString(descriptor);

  @override
  Future<ExplainResult> explain(QueryDescriptor d) {
    final compiled = _compiler.compileQuery(d);
    return MongoErrorMapper.wrap(() async {
      final result = await _connection.db.runCommand(
        _buildExplainCommand(compiled),
      );
      return parseExplainOutput(result);
    }, table: compiled.collection);
  }

  Map<String, Object> _buildExplainCommand(MongoCompileResult compiled) {
    final findSpec = <String, Object>{'find': compiled.collection};
    if (compiled.filter.isNotEmpty) findSpec['filter'] = compiled.filter;
    if (compiled.sort.isNotEmpty) findSpec['sort'] = compiled.sort;
    final projection = compiled.projection;
    if (projection != null) findSpec['projection'] = projection;
    final skip = compiled.skip;
    if (skip != null) findSpec['skip'] = skip;
    final limit = compiled.limit;
    if (limit != null) findSpec['limit'] = limit;
    return <String, Object>{'explain': findSpec, 'verbosity': 'executionStats'};
  }

  // ---- helpers ---------------------------------------------------

  Future<void> _createCollection(
    String name, {
    required bool ifNotExists,
  }) async {
    if (ifNotExists) {
      final existing = await _connection.db.getCollectionNames();
      if (existing.contains(name)) return;
    }
    await _connection.db.createCollection(name);
  }

  Future<void> _dropCollection(String name, {required bool ifExists}) async {
    if (ifExists) {
      final existing = await _connection.db.getCollectionNames();
      if (!existing.contains(name)) return;
    }
    await _connection.db.dropCollection(name);
  }

  Future<Object?> _scalarAggregate(AggregateDescriptor d, String op) =>
      MongoErrorMapper.wrap(() async {
        final column = _columnRequired(d);
        final filter = _compiler.compileFilter(d.where);
        // `modernAggregate` requires `List<Map<String, Object>>` — the
        // top-level stages must be non-nullable-valued. The nested
        // `$group` body remains `Object?`-valued so `_id: null`
        // (group-all) is preserved as a plain stage value.
        final pipeline = <Map<String, Object>>[
          if (filter.isNotEmpty) <String, Object>{r'$match': filter},
          <String, Object>{
            r'$group': <String, Object?>{
              '_id': null,
              'result': <String, Object?>{op: '\$$column'},
            },
          },
        ];
        final docs = await _connection.db
            .collection(d.table)
            .modernAggregate(pipeline)
            .toList();
        if (docs.isEmpty) return null;
        return docs.first['result'];
      }, table: d.table);

  String _columnRequired(AggregateDescriptor d) {
    final column = d.column;
    if (column == null) {
      throw QueryException(
        query: 'aggregate ${d.function.name} on "${d.table}"',
        message: '${d.function.name} requires a column',
      );
    }
    return column == 'id' ? '_id' : column;
  }

  Map<String, Object?> _projectReturning(
    Map<String, Object?> row,
    List<String>? returning,
  ) {
    if (returning == null) return row;
    return <String, Object?>{
      for (final column in returning) column: row[column],
    };
  }

  /// Shared key-swap core for both inbound and outbound aliasing.
  ///
  /// Walks [source] once, replacing the key [from] with [to] while
  /// leaving every other key and every value untouched. Used by all
  /// three boundary helpers below so the swap rule lives in exactly
  /// one place.
  Map<String, Object?> _swapIdKeys(
    Map<String, Object?> source,
    String from,
    String to,
  ) => <String, Object?>{
    for (final entry in source.entries)
      (entry.key == from ? to : entry.key): entry.value,
  };

  /// Converts a worm row into the shape mongo_dart accepts for
  /// `insertOne` / `insertMany`.
  ///
  /// `Map<String, dynamic>` is a documented interop boundary: the
  /// `mongo_dart` 0.9 driver's insert signatures require this exact
  /// type, so we materialise the swapped map into that shape rather
  /// than upcast at the call site.
  Map<String, dynamic> _aliasToMongo(Map<String, Object?> source) =>
      <String, dynamic>{
        for (final entry in _swapIdKeys(source, 'id', '_id').entries)
          entry.key: entry.value,
      };

  /// Inbound alias for documents the `mongo_dart` driver yields as
  /// `Map<String, dynamic>` (cursor rows, `findOne` results, insert
  /// write-result documents).
  ///
  /// The parameter type matches the driver's surface — another
  /// documented interop boundary. Values are widened to `Object?`
  /// in the literal below, then handed to [_swapIdKeys] for the
  /// canonical key swap.
  Map<String, Object?> _aliasFromMongo(Map<String, dynamic> source) =>
      _swapIdKeys(
        <String, Object?>{
          for (final entry in source.entries) entry.key: entry.value,
        },
        '_id',
        'id',
      );

  /// Inbound alias for documents already typed as
  /// `Map<String, Object?>` — typically constructed by the adapter
  /// itself rather than returned by the driver.
  Map<String, Object?> _aliasFromMongoDoc(Map<String, Object?> source) =>
      _swapIdKeys(source, '_id', 'id');

  Map<String, Object>? _maybeObjectMap(Map<String, int> source) {
    if (source.isEmpty) return null;
    return _toObjectMap(source);
  }

  Map<String, Object> _toObjectMap(Map<String, int> source) => <String, Object>{
    for (final entry in source.entries) entry.key: entry.value,
  };
}

/// Builds an [ExplainResult] from a MongoDB `explain` command
/// response.
///
/// Reads `executionStats.totalKeysExamined` to decide whether the
/// query planner satisfied any predicate from an index — a value
/// greater than zero means at least one index key was visited.
/// Serialises the entire response into [ExplainResult.raw] so the
/// strictness layer and diagnostic tooling have the full plan
/// available for logging.
///
/// Exposed at library level so the unit test can exercise the
/// parser with sample explain JSON without needing a live MongoDB
/// instance or a mocked driver.
ExplainResult parseExplainOutput(Map<String, Object?> explain) {
  final total = _readTotalKeysExamined(explain['executionStats']);
  return ExplainResult(usesIndex: total > 0, raw: jsonEncode(explain));
}

int _readTotalKeysExamined(Object? stats) {
  if (stats is! Map<String, Object?>) return 0;
  return switch (stats['totalKeysExamined']) {
    final int v => v,
    final num v => v.toInt(),
    _ => 0,
  };
}
