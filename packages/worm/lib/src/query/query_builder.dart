/// The fluent `QueryBuilder<T>` for the worm ORM.
library;

import 'dart:developer' as developer;

import 'package:meta/meta.dart';

import '../config/strictness_config.dart';
import '../exception/adapter_mismatch_exception.dart';
import '../exception/cast_exception.dart';
import '../exception/configuration_exception.dart';
import '../exception/full_table_scan_exception.dart';
import '../exception/model_not_found_exception.dart';
import '../exception/unsupported_operation_exception.dart';
import '../logging/explain_runner.dart';
import '../model/model.dart';
import '../pagination/cursor.dart';
import '../pagination/cursor_page.dart';
import '../pagination/page.dart';
import '../pagination/paginator.dart' as paginator;
import '../registry/worm.dart';
import '../relation/eager_loader.dart';
import '../relation/relation_field.dart';
import '../scope/global_scope.dart';
import '../scope/local_scope.dart';
import '../scope/soft_delete_scope.dart';
import 'adapter_dialect.dart';
import 'aggregate_descriptor.dart';
import 'delete_descriptor.dart';
import 'eager_load.dart';
import 'field.dart';
import 'field_operators.dart';
import 'insert_descriptor.dart';
import 'mongo_filter_compiler.dart';
import 'mongo_query_context.dart';
import 'operator.dart';
import 'predicate.dart';
import 'predicate_tree.dart';
import 'query_context.dart';
import 'query_descriptor.dart';
import 'sort_clause.dart';
import 'sort_direction.dart';
import 'sql_query_context.dart';
import 'update_descriptor.dart';

const MongoFilterCompiler _mongoCompiler = MongoFilterCompiler();

/// Fluent, type-safe query builder.
///
/// Builders are immutable: every chainable method
/// returns a fresh [QueryBuilder] carrying an updated
/// [QueryDescriptor]. Terminal methods (e.g.
/// [get], [count], [paginate]) execute the
/// underlying [QueryContext.adapter].
final class QueryBuilder<T extends Model> {
  /// Internal constructor preserving all builder
  /// state.
  const QueryBuilder._({
    required this.context,
    required this.descriptor,
    required this.disabledGlobalScopes,
    required this.allGlobalScopesDisabled,
    required this.eagerLoads,
    required this.aggregates,
    required this.strictness,
  });

  /// Creates a fresh builder targeting [context].
  QueryBuilder.from(
    QueryContext<T> context, {
    StrictnessConfig strictness = const StrictnessConfig(),
  }) : this._(
         context: context,
         descriptor: QueryDescriptor(table: context.table),
         disabledGlobalScopes: const <String>{},
         allGlobalScopesDisabled: false,
         eagerLoads: const <EagerLoad>[],
         aggregates: const <AggregateInjection>[],
         strictness: strictness,
       );

  /// Per-model context (adapter, table, hydrator,
  /// scopes, relations).
  final QueryContext<T> context;

  /// Current accumulated query descriptor.
  final QueryDescriptor descriptor;

  /// Names of global scopes the user has bypassed.
  /// Populated by typed [withoutGlobalScope]; stored as
  /// strings so [_applyGlobalScopes] can match by the
  /// scope's declared [GlobalScope.name].
  final Set<String> disabledGlobalScopes;

  /// When `true`, no global scope is applied.
  final bool allGlobalScopesDisabled;

  /// Eager-load entries to resolve after hydration.
  final List<EagerLoad> eagerLoads;

  /// Aggregate injections to populate per loaded
  /// model.
  final List<AggregateInjection> aggregates;

  /// Active strictness configuration.
  final StrictnessConfig strictness;

  // ---------- chainable / fluent ----------

  /// Add a WHERE predicate AND-combined with the
  /// existing tree.
  ///
  /// Three call shapes are supported:
  ///
  /// - `where(predicateTree)` — composed via field
  ///   operator extensions.
  /// - `where(field, value)` — sugar for
  ///   `where(field, Operator.eq, value)`.
  /// - `where(field, op, value)` — explicit operator.
  QueryBuilder<T> where(Object first, [Object? second, Object? third]) {
    final tree = _coercePredicate(first, second, third);
    final existing = descriptor.where;
    final next = existing == null ? tree : existing.and(tree);
    return _copy(descriptor: descriptor.copyWith(where: next));
  }

  /// Add a WHERE predicate OR-combined with the
  /// existing tree. Accepts the same shapes as
  /// [where].
  QueryBuilder<T> orWhere(Object first, [Object? second, Object? third]) {
    final tree = _coercePredicate(first, second, third);
    final existing = descriptor.where;
    final next = existing == null ? tree : existing.or(tree);
    return _copy(descriptor: descriptor.copyWith(where: next));
  }

  /// Group a sub-builder's predicates inside
  /// parentheses.
  ///
  /// `qb.where(foo).whereGroup((q) => q.where(a).orWhere(b))`
  /// produces `foo AND (a OR b)`.
  QueryBuilder<T> whereGroup(
    QueryBuilder<T> Function(QueryBuilder<T> inner) build,
  ) {
    // Inner builder runs with scopes disabled so the
    // global WHERE clauses cannot leak into the
    // grouped fragment — the outer builder still
    // applies them at execution time.
    final innerStart = QueryBuilder<T>._(
      context: context,
      descriptor: QueryDescriptor(table: context.table),
      disabledGlobalScopes: disabledGlobalScopes,
      allGlobalScopesDisabled: true,
      eagerLoads: eagerLoads,
      aggregates: aggregates,
      strictness: strictness,
    );
    final built = build(innerStart);
    final inner = built.descriptor.where;
    if (inner == null) return this;
    final grouped = GroupNode(inner);
    final existing = descriptor.where;
    final next = existing == null ? grouped : existing.and(grouped);
    return _copy(descriptor: descriptor.copyWith(where: next));
  }

  /// AND a subquery EXISTS predicate.
  QueryBuilder<T> whereExists<X extends Model>(QueryBuilder<X> subquery) =>
      where(ExistsNode(subquery.descriptor));

  /// AND a subquery NOT EXISTS predicate.
  QueryBuilder<T> whereNotExists<X extends Model>(QueryBuilder<X> subquery) =>
      where(ExistsNode(subquery.descriptor, negated: true));

  /// AND a column-to-column comparison.
  QueryBuilder<T> whereColumn(
    Field<Object?> left,
    Field<Object?> right, {
    Operator operator = Operator.eq,
  }) => where(
    ColumnNode(
      leftField: left.name,
      leftTable: left.tableName,
      rightField: right.name,
      rightTable: right.tableName,
      operator: operator,
    ),
  );

  /// AND a raw SQL fragment.
  ///
  /// Escape hatch: bypasses every ORM safety guarantee
  /// (type checking, parameter quoting, predicate
  /// composition rules) and emits [sql] verbatim under
  /// the WHERE tree. Use only when no typed alternative
  /// exists. Mongo and in-memory adapters reject
  /// queries that contain a [RawNode] at execution
  /// time.
  ///
  /// `allowRaw: true` must be passed explicitly to
  /// surface intent at the call site; omitting it
  /// throws [ConfigurationException].
  QueryBuilder<T> whereRaw(
    String sql, {
    List<Object?> parameters = const <Object?>[],
    bool allowRaw = false,
  }) {
    if (!allowRaw) {
      throw const ConfigurationException(
        key: 'whereRaw.allowRaw',
        message: 'whereRaw requires allowRaw: true to surface intent',
      );
    }
    return where(RawNode(sql, parameters: parameters));
  }

  /// Append an ORDER BY clause.
  QueryBuilder<T> orderBy(Field<Object?> field, {bool descending = false}) {
    final clause = SortClause(
      field.name,
      tableName: field.tableName,
      direction: descending ? SortDirection.desc : SortDirection.asc,
    );
    return _copy(
      descriptor: descriptor.copyWith(
        orderBy: <SortClause>[...descriptor.orderBy, clause],
      ),
    );
  }

  /// Set the LIMIT.
  QueryBuilder<T> limit(int value) =>
      _copy(descriptor: descriptor.copyWith(limit: value));

  /// Set the OFFSET.
  QueryBuilder<T> offset(int value) =>
      _copy(descriptor: descriptor.copyWith(offset: value));

  /// Restrict the projected columns.
  QueryBuilder<T> select(List<Field<Object?>> fields) => _copy(
    descriptor: descriptor.copyWith(
      columns: <String>[for (final f in fields) f.name],
    ),
  );

  /// Return only distinct rows.
  QueryBuilder<T> distinct() =>
      _copy(descriptor: descriptor.copyWith(distinct: true));

  /// Bypass the global scope of type [X] on this
  /// builder.
  ///
  /// Resolves [X] against the registered scopes in
  /// `QueryContext.globalScopes` via `is X` and records
  /// the matched scope's `GlobalScope.name` in
  /// [disabledGlobalScopes]. When no registered scope
  /// satisfies `is X`, returns `this` unchanged (no-op).
  QueryBuilder<T> withoutGlobalScope<X extends GlobalScope<Model>>() {
    final disabled = <String>{};
    for (final scope in context.globalScopes) {
      if (scope is X) disabled.add(scope.name);
    }
    if (disabled.isEmpty) return this;
    return _copy(
      disabledGlobalScopes: <String>{...disabledGlobalScopes, ...disabled},
    );
  }

  /// Bypass every global scope on this builder.
  QueryBuilder<T> withoutGlobalScopes() => _copy(allGlobalScopesDisabled: true);

  /// Apply a [LocalScope] to this builder.
  QueryBuilder<T> scope(LocalScope<T> scope) => scope.apply(this);

  /// Include soft-deleted rows by bypassing the
  /// soft-delete scope via the typed bypass.
  QueryBuilder<T> withTrashed() => withoutGlobalScope<SoftDeleteScope<Model>>();

  /// Return only soft-deleted rows.
  QueryBuilder<T> onlyTrashed({String column = 'deleted_at'}) =>
      withTrashed().where(Field<Object?>(column).isNotNull());

  /// Eager-load relations named by raw string [paths]
  /// (dot-notation for nesting, e.g. `'posts.comments'`).
  QueryBuilder<T> withRelationPaths(List<String> paths) => _copy(
    eagerLoads: <EagerLoad>[...eagerLoads, for (final p in paths) EagerLoad(p)],
  );

  /// Eager-load relations referenced by typed [relations] companions.
  ///
  /// ```dart
  /// query.withRelations(<RelationField<Model, Model>>[
  ///   User$.posts,
  ///   User$.profile,
  /// ]);
  /// ```
  QueryBuilder<T> withRelations(List<RelationField<Model, Model>> relations) =>
      withRelationPaths(<String>[for (final r in relations) r.name]);

  /// Eager-load the relation named by [field], optionally
  /// constrained by [constraint].
  ///
  /// [constraint] is a [PredicateTree] (typically built from typed
  /// [Field] companions, e.g. `Post$.published.eq(true)`) that the
  /// child SELECT AND-merges into its `WHERE` clause. Pass `null`
  /// (or omit) to eager-load the relation without filtering.
  ///
  /// ```dart
  /// query.withRelation(User$.posts, Post$.published.eq(true));
  /// ```
  QueryBuilder<T> withRelation<P extends Model, R extends Model>(
    RelationField<P, R> field, [
    PredicateTree? constraint,
  ]) => _copy(
    eagerLoads: <EagerLoad>[
      ...eagerLoads,
      EagerLoad(field.name, constrain: constraint),
    ],
  );

  /// Eager-load a relationship tree with a separate constraint at each level.
  QueryBuilder<T> withEagerLoad(EagerLoad load) =>
      _copy(eagerLoads: <EagerLoad>[...eagerLoads, load]);

  /// Eager-load the nested relation [path] produced by
  /// [RelationField.include].
  ///
  /// ```dart
  /// query.withPath(User$.posts.include([Post$.comments]));
  /// ```
  QueryBuilder<T> withPath(RelationPath path) =>
      _copy(eagerLoads: <EagerLoad>[...eagerLoads, EagerLoad(path.path)]);

  /// Spec-vocabulary alias for [withPath]; eager-load the nested
  /// relation [spec] produced by [RelationField.include].
  ///
  /// ```dart
  /// query.withNested(User$.posts.include([Post$.comments]));
  /// ```
  QueryBuilder<T> withNested(RelationLoadSpec spec) => withPath(spec);

  /// Inject a count of related rows under
  /// `<relation>Count` on each loaded model.
  ///
  /// Pass [filter] (a [PredicateTree], typically built from typed
  /// `Field` companions) to count only matching related rows, e.g.
  /// `withCount(User$.posts.name, filter: Post$.published.eq(true))`.
  QueryBuilder<T> withCount(
    String relation, {
    String? injectKey,
    PredicateTree? filter,
  }) => _copy(
    aggregates: <AggregateInjection>[
      ...aggregates,
      AggregateInjection(
        relationName: relation,
        kind: AggregateKind.count,
        injectionKey: injectKey ?? '${relation}Count',
        filter: filter,
      ),
    ],
  );

  /// Inject a sum of [column] from the related table
  /// under `<relation>Sum` on each loaded model.
  QueryBuilder<T> withSum(
    String relation,
    String column, {
    String? injectKey,
  }) => _copy(
    aggregates: <AggregateInjection>[
      ...aggregates,
      AggregateInjection(
        relationName: relation,
        kind: AggregateKind.sum,
        injectionKey: injectKey ?? '${relation}Sum',
        column: column,
      ),
    ],
  );

  /// Inject a `<relation>Exists` boolean on each
  /// loaded model.
  QueryBuilder<T> withExists(String relation, {String? injectKey}) => _copy(
    aggregates: <AggregateInjection>[
      ...aggregates,
      AggregateInjection(
        relationName: relation,
        kind: AggregateKind.exists,
        injectionKey: injectKey ?? '${relation}Exists',
      ),
    ],
  );

  // ---------- terminal / executing ----------

  /// Execute and return all hydrated rows.
  Future<List<T>> get() async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    final rows = await context.adapter.select(scoped.descriptor);
    final items = <T>[for (final row in rows) context.hydrate(row)];
    await EagerLoader.run(
      context: context,
      parents: items,
      loads: eagerLoads,
      aggregates: aggregates,
    );
    return items;
  }

  /// Return the first matching row, or `null`.
  Future<T?> first() async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    final row = await context.adapter.selectOne(scoped.limit(1).descriptor);
    if (row == null) return null;
    final item = context.hydrate(row);
    await EagerLoader.run(
      context: context,
      parents: <T>[item],
      loads: eagerLoads,
      aggregates: aggregates,
    );
    return item;
  }

  /// Return the first matching row or throw
  /// [ModelNotFoundException].
  Future<T> firstOrFail() async {
    final found = await first();
    if (found == null) {
      throw ModelNotFoundException(
        model: '$T',
        id: '<query>',
        message: 'No $T matches the query',
      );
    }
    return found;
  }

  /// Look up by primary key, or `null`.
  Future<T?> find(Object id) async {
    final field = Field<Object?>(context.primaryKey);
    final scoped = _applyGlobalScopes().where(field.eq(id)).limit(1);
    final row = await context.adapter.selectOne(scoped.descriptor);
    if (row == null) return null;
    final item = context.hydrate(row);
    await EagerLoader.run(
      context: context,
      parents: <T>[item],
      loads: eagerLoads,
      aggregates: aggregates,
    );
    return item;
  }

  /// Look up by primary key or throw
  /// [ModelNotFoundException].
  Future<T> findOrFail(Object id) async {
    final found = await find(id);
    if (found == null) {
      throw ModelNotFoundException(
        model: '$T',
        id: id,
        message: 'No $T with id "$id"',
      );
    }
    return found;
  }

  /// Count of matching rows.
  Future<int> count() async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    return context.adapter.count(
      AggregateDescriptor.count(
        table: scoped.descriptor.table,
        where: scoped.descriptor.where,
      ),
    );
  }

  /// Sum of [field] across matching rows. Pushes down
  /// to the adapter — never iterates rows.
  Future<num?> sum(Field<num> field) async => context.adapter.sum(
    _aggregateDescriptor(AggregateFunction.sum, field.name),
  );

  /// Average of [field] across matching rows. Pushes
  /// down to the adapter — never iterates rows.
  Future<double?> avg(Field<num> field) async => context.adapter.avg(
    _aggregateDescriptor(AggregateFunction.avg, field.name),
  );

  /// Minimum value of [field] across matching rows.
  Future<V?> min<V extends Object>(Field<V> field) async {
    final value = await context.adapter.min(
      _aggregateDescriptor(AggregateFunction.min, field.name),
    );
    return _narrowExtremum<V>(field, value);
  }

  /// Maximum value of [field] across matching rows.
  Future<V?> max<V extends Object>(Field<V> field) async {
    final value = await context.adapter.max(
      _aggregateDescriptor(AggregateFunction.max, field.name),
    );
    return _narrowExtremum<V>(field, value);
  }

  /// Build an [AggregateDescriptor] from the scoped
  /// descriptor for [function] over [column].
  AggregateDescriptor _aggregateDescriptor(
    AggregateFunction function,
    String column,
  ) {
    final scoped = _applyGlobalScopes();
    return AggregateDescriptor(
      table: scoped.descriptor.table,
      function: function,
      column: column,
      where: scoped.descriptor.where,
    );
  }

  /// Narrow an adapter-returned `Object?` extremum to
  /// the caller's [V]. Returns `null` when no rows
  /// match; throws [CastException] when a non-null
  /// value's runtime type is incompatible with [V] so
  /// the mismatch surfaces instead of being silently
  /// swallowed.
  V? _narrowExtremum<V extends Object>(Field<V> field, Object? value) {
    if (value == null) return null;
    if (value is V) return value;
    throw CastException(
      field: field.name,
      fromType: value.runtimeType.toString(),
      toType: V.toString(),
      message:
          'min/max returned ${value.runtimeType} for column "${field.name}" '
          'but $V was requested',
    );
  }

  /// Whether at least one row matches.
  /// Whether any row matches.
  ///
  /// Issues a `LIMIT 1` probe (via the adapter's `selectOne`) that
  /// short-circuits at the first matching row, rather than a full
  /// `COUNT(*)` that scans every match.
  Future<bool> exists() async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    return await context.adapter.selectOne(scoped.descriptor) != null;
  }

  /// Pluck a single column from all matching rows.
  Future<List<V>> pluck<V>(Field<V> field) async {
    final scoped =
        (_applyGlobalScopes().._guardFullTableScan(destructive: false)).select(
          <Field<Object?>>[
            Field<Object?>(field.name, tableName: field.tableName),
          ],
        );
    final rows = await context.adapter.select(scoped.descriptor);
    return <V>[
      for (final row in rows)
        if (row[field.name] case final V v) v,
    ];
  }

  /// Bulk update without hydrating models.
  Future<int> update(Map<String, Object?> values) async {
    final scoped = _applyGlobalScopes().._guardFullTableScan(destructive: true);
    return context.adapter.update(
      UpdateDescriptor(
        table: scoped.descriptor.table,
        values: values,
        where: scoped.descriptor.where,
      ),
    );
  }

  /// Bulk delete without hydrating models.
  Future<int> delete() async {
    final scoped = _applyGlobalScopes().._guardFullTableScan(destructive: true);
    return context.adapter.delete(
      DeleteDescriptor(
        table: scoped.descriptor.table,
        where: scoped.descriptor.where,
      ),
    );
  }

  /// Bulk-insert [rows] in a single adapter call and return the
  /// hydrated models.
  ///
  /// Lifecycle hooks and validation do **not** fire — this is the
  /// fast path for seeding and bulk imports. Use `Model.save()` when
  /// per-row events are required.
  Future<List<T>> insertMany(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return <T>[];
    final inserted = await context.adapter.insertMany(
      InsertManyDescriptor(table: context.table, rows: rows),
    );
    return <T>[for (final row in inserted) context.hydrate(row)];
  }

  /// Offset-based paginate.
  Future<Page<T>> paginate({int page = 1, int perPage = 15}) async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    return paginator.paginate<T>(
      context: context,
      descriptor: scoped.descriptor,
      page: page,
      perPage: perPage,
      loads: eagerLoads,
      aggregates: aggregates,
    );
  }

  /// Cursor-based paginate ordered by primary key
  /// ascending.
  ///
  /// Pass either a decoded [cursor] or the encoded token
  /// via [after]; both are equivalent.
  Future<CursorPage<T>> cursorPaginate({
    int perPage = 15,
    Cursor? cursor,
    String? after,
  }) async {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    return paginator.cursorPaginate<T>(
      context: context,
      descriptor: scoped.descriptor,
      perPage: perPage,
      cursor: cursor,
      after: after,
      loads: eagerLoads,
      aggregates: aggregates,
    );
  }

  // ---------- streaming terminals ----------

  /// Stream matching rows as hydrated models with
  /// bounded memory. Delegates to
  /// `adapter.stream(descriptor)`.
  Stream<T> stream() async* {
    final scoped = _applyGlobalScopes()
      .._guardFullTableScan(destructive: false);
    final rowStream = context.adapter.stream(scoped.descriptor);
    await for (final row in rowStream) {
      yield context.hydrate(row);
    }
  }

  /// Invoke [callback] with successive lists of at
  /// most [size] hydrated models until the stream is
  /// exhausted.
  Future<void> chunk(
    int size,
    Future<void> Function(List<T> rows) callback,
  ) async {
    if (size <= 0) {
      throw const ConfigurationException(
        key: 'chunk.size',
        message: 'chunk size must be > 0',
      );
    }
    var buffer = <T>[];
    await for (final item in stream()) {
      buffer.add(item);
      if (buffer.length == size) {
        await callback(buffer);
        buffer = <T>[];
      }
    }
    if (buffer.isNotEmpty) await callback(buffer);
  }

  /// Stream chunks of at most [size] hydrated models.
  Stream<List<T>> streamChunks(int size) async* {
    if (size <= 0) {
      throw const ConfigurationException(
        key: 'streamChunks.size',
        message: 'streamChunks size must be > 0',
      );
    }
    var buffer = <T>[];
    await for (final item in stream()) {
      buffer.add(item);
      if (buffer.length == size) {
        yield buffer;
        buffer = <T>[];
      }
    }
    if (buffer.isNotEmpty) yield buffer;
  }

  // ---------- query inspection ----------

  /// Render the scoped descriptor as a SQL string by
  /// delegating to the adapter's compileToString. Pure
  /// compile — never executes.
  String toSql() =>
      context.adapter.compileToString(_applyGlobalScopes().descriptor);

  /// Render the scoped descriptor's WHERE tree as a
  /// canonical Mongo filter JSON document.
  String toMongoFilter() =>
      _mongoCompiler.compile(_applyGlobalScopes().descriptor);

  /// Pure observer: log a summary of this builder via
  /// `dart:developer` and return this for fluent
  /// chaining. Does not mutate any state, does not
  /// execute the query, and never throws.
  QueryBuilder<T> debug() {
    try {
      developer.log(_debugSummary(), name: 'worm.query');
    } on Object {
      // debug() is a best-effort observer — swallow
      // failures so it cannot break the fluent chain.
    }
    // ignore: avoid_returning_this — chainable observer.
    return this;
  }

  String _debugSummary() {
    final buffer = StringBuffer('QueryBuilder<$T>(')
      ..write('table=${descriptor.table}')
      ..write(', where=')
      ..write(descriptor.where?.toMap() ?? '<none>')
      ..write(', orderBy=${descriptor.orderBy.length}')
      ..write(', limit=${descriptor.limit}')
      ..write(', offset=${descriptor.offset}')
      ..write(', distinct=${descriptor.distinct}')
      ..write(', eagerLoads=${eagerLoads.length}')
      ..write(', aggregates=${aggregates.length}')
      ..write(')');
    return buffer.toString();
  }

  /// Ask the adapter to produce an EXPLAIN plan for
  /// the scoped descriptor.
  ///
  /// Throws [UnsupportedOperationException] when the
  /// adapter does not mix in [ExplainCapable].
  Future<ExplainResult> explain() async {
    final adapter = context.adapter;
    if (adapter case final ExplainCapable explainer) {
      return explainer.explain(_applyGlobalScopes().descriptor);
    }
    throw UnsupportedOperationException(
      operation: 'explain',
      adapter: adapterName(adapter),
      message: 'Adapter ${adapterName(adapter)} does not mix in ExplainCapable',
    );
  }

  // ---------- adapter-context gates ----------

  /// Enter a SQL-specific chainable context. Throws
  /// [AdapterMismatchException] when the underlying
  /// adapter's `adapterType` is not [AdapterType.sql].
  R sql<R>(R Function(SqlQueryContext<T> sql) callback) {
    if (context.adapter.adapterType != AdapterType.sql) {
      throw AdapterMismatchException(
        expectedAdapter: 'worm_postgres',
        actualAdapter: adapterName(context.adapter),
        message:
            '.sql(...) requires a SQL-capable adapter '
            '(expected: worm_postgres, actual: '
            '${adapterName(context.adapter)})',
      );
    }
    return callback(SqlQueryContext<T>(this));
  }

  /// Enter a Mongo-specific chainable context. Throws
  /// [AdapterMismatchException] when the underlying
  /// adapter's `adapterType` is not
  /// [AdapterType.mongodb].
  R mongo<R>(R Function(MongoQueryContext<T> mongo) callback) {
    if (context.adapter.adapterType != AdapterType.mongodb) {
      throw AdapterMismatchException(
        expectedAdapter: 'worm_mongodb',
        actualAdapter: adapterName(context.adapter),
        message:
            '.mongo(...) requires a Mongo-capable adapter '
            '(expected: worm_mongodb, actual: '
            '${adapterName(context.adapter)})',
      );
    }
    return callback(MongoQueryContext<T>(this));
  }

  // ---------- internals ----------

  // PredicateTree match must come first so existing
  // single-argument callers are unaffected by the
  // overload dispatch below.
  PredicateTree _coercePredicate(Object first, Object? second, Object? third) =>
      switch ((first, second, third)) {
        (final PredicateTree tree, null, null) => tree,
        (PredicateTree(), _, _) => throw const ConfigurationException(
          key: 'where.shape',
          message:
              'where(PredicateTree) does not accept additional positional '
              'arguments',
        ),
        // 3-arg happy path: (Field, Operator, value).
        (final Field<Object?> field, final Operator op, final Object? value)
            when third != null =>
          LeafNode(
            Predicate(
              fieldName: field.name,
              tableName: field.tableName,
              operator: op,
              value: value,
            ),
          ),
        // 3-arg form but the operator slot is not an Operator.
        (Field<Object?>(), _, _) when third != null =>
          throw ArgumentError.value(
            second,
            'operator',
            'where(field, operator, value): expected Operator, got '
                '${second.runtimeType}',
          ),
        // 2-arg sugar: (Field, value) → equals.
        (final Field<Object?> field, final Object? value, null) => LeafNode(
          Predicate(
            fieldName: field.name,
            tableName: field.tableName,
            operator: Operator.eq,
            value: value,
          ),
        ),
        // 2-arg shape where the first slot is not a Field.
        (_, _, null) when second != null => throw ArgumentError.value(
          first,
          'field',
          'where(field, value): expected Field, got ${first.runtimeType}',
        ),
        // Anything else (e.g. single non-PredicateTree).
        _ => throw ConfigurationException(
          key: 'where.shape',
          message:
              'Invalid where(...) shape — expected PredicateTree, '
              '(field, value) or (field, Operator, value); got '
              '${first.runtimeType}',
        ),
      };

  /// Apply enabled global scopes in registration
  /// order. Skips disabled and "all disabled" cases.
  QueryBuilder<T> _applyGlobalScopes() {
    if (allGlobalScopesDisabled) return this;
    var current = this;
    for (final scope in context.globalScopes) {
      if (disabledGlobalScopes.contains(scope.name)) continue;
      current = _applyScope(scope, current);
    }
    return current;
  }

  QueryBuilder<T> _applyScope(
    GlobalScope<Model> scope,
    QueryBuilder<T> builder,
  ) {
    if (scope is GlobalScope<T>) return scope.apply(builder);
    final modelContext = QueryContext<Model>(
      adapter: builder.context.adapter,
      table: builder.context.table,
      hydrate: (_) => throw const ConfigurationException(
        key: 'scope.shim',
        message: 'Scope shim hydrator should never run',
      ),
      primaryKey: builder.context.primaryKey,
      globalScopes: builder.context.globalScopes,
      relations: builder.context.relations,
    );
    final modelBuilder = QueryBuilder<Model>._(
      context: modelContext,
      descriptor: builder.descriptor,
      disabledGlobalScopes: builder.disabledGlobalScopes,
      allGlobalScopesDisabled: builder.allGlobalScopesDisabled,
      eagerLoads: builder.eagerLoads,
      aggregates: builder.aggregates,
      strictness: builder.strictness,
    );
    final scoped = scope.apply(modelBuilder);
    return builder._copy(descriptor: scoped.descriptor);
  }

  /// Effective full-table-scan flag.
  ///
  /// Combines the builder's local [strictness] with [Worm.strictness]
  /// so a globally strict runtime guards builders that were created
  /// before [Worm.initialize] ran.
  bool get _effectivePreventFullTableScans {
    if (strictness.preventFullTableScans) return true;
    return Worm.strictness.preventFullTableScans;
  }

  /// Effective destructive-without-where flag.
  ///
  /// `preventFullTableScans` is the canonical umbrella flag for
  /// "do not run a query that touches every row"; this getter folds
  /// it together with the historical
  /// [StrictnessConfig.preventDestructiveWithoutWhere] toggle so a
  /// destructive write without WHERE is blocked when either flag is
  /// set (locally or globally).
  bool get _effectivePreventDestructive {
    if (strictness.preventDestructiveWithoutWhere) return true;
    if (Worm.strictness.preventDestructiveWithoutWhere) return true;
    return _effectivePreventFullTableScans;
  }

  /// Throws [FullTableScanException] when the scoped descriptor
  /// would run without a WHERE clause and strictness blocks it.
  ///
  /// Honours [Worm.isUnsafe] — any call inside `Worm.unsafe(...)` is
  /// a no-op so callers can opt into a deliberate full scan.
  void _guardFullTableScan({required bool destructive}) {
    if (Worm.isUnsafe) return;
    if (descriptor.where != null) return;
    if (destructive) {
      if (!_effectivePreventDestructive) return;
      throw FullTableScanException(
        table: descriptor.table,
        message:
            'Destructive query on "${descriptor.table}" without WHERE '
            'is blocked by strict mode (preventFullTableScans / '
            'preventDestructiveWithoutWhere). Add a .where(...) or '
            'wrap the call in Worm.unsafe(() async { ... }).',
      );
    }
    if (!_effectivePreventFullTableScans) return;
    throw FullTableScanException(
      table: descriptor.table,
      message:
          'Full-table scan of "${descriptor.table}" is blocked by '
          'preventFullTableScans. Add a .where(...) or wrap the call '
          'in Worm.unsafe(() async { ... }).',
    );
  }

  /// Returns a copy carrying [descriptor]. Low-level seam used by the
  /// `.sql()` / `.mongo()` adapter contexts to thread join / groupBy /
  /// having state through the immutable builder.
  @internal
  QueryBuilder<T> withDescriptor(QueryDescriptor descriptor) =>
      _copy(descriptor: descriptor);

  QueryBuilder<T> _copy({
    QueryDescriptor? descriptor,
    Set<String>? disabledGlobalScopes,
    bool? allGlobalScopesDisabled,
    List<EagerLoad>? eagerLoads,
    List<AggregateInjection>? aggregates,
    StrictnessConfig? strictness,
  }) => QueryBuilder<T>._(
    context: context,
    descriptor: descriptor ?? this.descriptor,
    disabledGlobalScopes: disabledGlobalScopes ?? this.disabledGlobalScopes,
    allGlobalScopesDisabled:
        allGlobalScopesDisabled ?? this.allGlobalScopesDisabled,
    eagerLoads: eagerLoads ?? this.eagerLoads,
    aggregates: aggregates ?? this.aggregates,
    strictness: strictness ?? this.strictness,
  );
}
