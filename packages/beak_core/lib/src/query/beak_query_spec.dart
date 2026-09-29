import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/list_equality.dart';
import '../model/beak_field_ref.dart';
import '../relations/beak_relationship.dart';
import 'beak_filter.dart';
import 'beak_pagination.dart';
import 'beak_relation_load.dart';
import 'beak_sort.dart';
import '../common/json_support.dart';

/// Beak's wire contract: a typed, losslessly JSON-serializable description
/// of a query.
///
/// Application code starts a spec from its model — `const PostModel().query()`
/// — and refines it through the immutable copy-builders ([withFilter],
/// [orderBy], [withRelation], [searching], [paginate]) with the model's
/// generated field references, never key strings. The frontend ships it as
/// JSON; the backend decodes it with [fromJson] and translates it to the
/// ORM's query builder. The spec references column and relation *keys* only,
/// keeping it ORM-neutral.
///
/// Each copy-builder returns a new spec, so they chain fluently and the
/// original is never mutated:
///
/// ```dart
/// final spec = const PostModel()
///     .query(filter: PostModel.status.eq('published'))
///     .withRelation(PostModel.author.relation)
///     .orderBy(PostModel.createdAt, descending: true)
///     .paginate(page: 2, perPage: 50);
///
/// // Ship it across the wire, then rebuild it losslessly on the backend.
/// final BeakQuerySpec decoded = BeakQuerySpec.fromJson(spec.toJson());
/// ```
///
/// The constructor, which takes the table's stored name, is the wire-level
/// path for decoders and data-source adapters.
@immutable
final class BeakQuerySpec {
  // --8<-- [start:BeakQuerySpec]
  /// Creates a query over the table stored as [table].
  ///
  /// The wire-level constructor; application code calls `model.query()`,
  /// which fills [table] in from the model.
  const BeakQuerySpec({
    required this.table,
    this.filter,
    this.sorts = const [],
    this.search,
    this.relationLoads = const [],
    this.pagination = const BeakPagination(),
    this.withTrashed = false,
  });
  // --8<-- [end:BeakQuerySpec]

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Only `table` is required: every other key falls back to the same default
  /// the constructor declares, so `{"table": "products"}` is a valid request
  /// body. [toJson] still writes every key, leaving the encoded form — and
  /// every consumer of it — unchanged.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakQuerySpec fromJson(Map<String, Object?> json) {
    final String table = requireJsonString(json, 'table', 'BeakQuerySpec');
    if (table.isEmpty) {
      throw const BeakConfigurationException(
        'BeakQuerySpec JSON key "table" must not be empty.',
      );
    }
    final Map<String, Object?>? filterJson = optionalJsonMap(
      json,
      'filter',
      'BeakQuerySpec',
    );
    final Map<String, Object?>? searchJson = optionalJsonMap(
      json,
      'search',
      'BeakQuerySpec',
    );
    final Map<String, Object?>? paginationJson = optionalJsonMap(
      json,
      'pagination',
      'BeakQuerySpec',
    );
    return BeakQuerySpec(
      table: table,
      filter: filterJson == null ? null : BeakFilter.fromJson(filterJson),
      sorts: [
        for (final sort in optionalJsonMapList(json, 'sorts', 'BeakQuerySpec'))
          BeakSort.fromJson(sort),
      ],
      search: searchJson == null ? null : BeakSearch.fromJson(searchJson),
      relationLoads: [
        for (final load in optionalJsonMapList(
          json,
          'relations',
          'BeakQuerySpec',
        ))
          BeakRelationLoad.fromJson(load),
      ],
      pagination: paginationJson == null
          ? const BeakPagination()
          : BeakPagination.fromJson(paginationJson),
      withTrashed: optionalJsonBool(
        json,
        'withTrashed',
        'BeakQuerySpec',
        orElse: false,
      ),
    );
  }

  /// Physical table/collection name of the queried model.
  final String table;

  /// The predicate records must satisfy, if any.
  final BeakFilter? filter;

  /// Ordering directives, applied in order.
  final List<BeakSort> sorts;

  /// The full-text search directive, if any.
  final BeakSearch? search;

  /// Relations to eager-load with the results.
  final List<BeakRelationLoad> relationLoads;

  /// The paging window of the results.
  final BeakPagination pagination;

  /// Whether soft-deleted records are included.
  final bool withTrashed;

  /// This spec as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'table': table,
    'filter': filter?.toJson(),
    'sorts': [for (final sort in sorts) sort.toJson()],
    'search': search?.toJson(),
    'relations': [for (final load in relationLoads) load.toJson()],
    'pagination': pagination.toJson(),
    'withTrashed': withTrashed,
  };

  // --8<-- [start:withFilter]
  /// Returns a copy with [filter] AND-merged into the existing predicate:
  /// the first filter is taken as-is, later ones join an ever-growing
  /// conjunction.
  BeakQuerySpec withFilter(BeakFilter filter) => _copy(
    filter: switch (this.filter) {
      null => filter,
      final BeakAndFilter existing => BeakAndFilter([
        ...existing.filters,
        filter,
      ]),
      final BeakFilter existing => BeakAndFilter([existing, filter]),
    },
  );
  // --8<-- [end:withFilter]

  /// Returns a copy additionally ordered by [field].
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship: results are ordered by their own columns only.
  BeakQuerySpec orderBy(
    BeakScalarField<Object> field, {
    bool descending = false,
  }) => _copy(
    sorts: [...sorts, descending ? field.descending() : field.ascending()],
  );

  /// Returns a copy additionally eager-loading [relation], optionally
  /// constrained by [constraint].
  BeakQuerySpec withRelation(
    BeakRelationship relation, {
    BeakFilter? constraint,
  }) => _copy(
    relationLoads: [
      ...relationLoads,
      BeakRelationLoad(relation.key, filter: constraint),
    ],
  );

  /// Returns a copy searching for [term] across [fields], which may reach
  /// through a relationship.
  BeakQuerySpec searching(String term, List<BeakScalarField<Object>> fields) =>
      _copy(
        search: BeakSearch(term, [
          for (final field in fields) field.qualifiedKey,
        ]),
      );

  /// Returns a copy with an updated paging window; either half keeps its
  /// current value when omitted.
  BeakQuerySpec paginate({int? page, int? perPage}) => _copy(
    pagination: BeakPagination(
      page: page ?? pagination.page,
      perPage: perPage ?? pagination.perPage,
    ),
  );

  BeakQuerySpec _copy({
    BeakFilter? filter,
    List<BeakSort>? sorts,
    BeakSearch? search,
    List<BeakRelationLoad>? relationLoads,
    BeakPagination? pagination,
  }) => BeakQuerySpec(
    table: table,
    filter: filter ?? this.filter,
    sorts: sorts ?? this.sorts,
    search: search ?? this.search,
    relationLoads: relationLoads ?? this.relationLoads,
    pagination: pagination ?? this.pagination,
    withTrashed: withTrashed,
  );

  @override
  bool operator ==(Object other) =>
      other is BeakQuerySpec &&
      other.table == table &&
      other.filter == filter &&
      listEquals(other.sorts, sorts) &&
      other.search == search &&
      listEquals(other.relationLoads, relationLoads) &&
      other.pagination == pagination &&
      other.withTrashed == withTrashed;

  @override
  int get hashCode => Object.hash(
    table,
    filter,
    Object.hashAll(sorts),
    search,
    Object.hashAll(relationLoads),
    pagination,
    withTrashed,
  );

  @override
  String toString() =>
      'BeakQuerySpec($table, filter: $filter, sorts: $sorts, '
      'search: $search, relations: $relationLoads, pagination: $pagination, '
      'withTrashed: $withTrashed)';
}

/// A full-text search directive: a [term] matched against the columns named
/// by [columnKeys].
///
/// User code obtains searches through the spec's typed `searching` builder,
/// which reads the keys from typed fields.
@immutable
final class BeakSearch {
  /// Creates a search for [term] across [columnKeys].
  const BeakSearch(this.term, this.columnKeys);

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Both `term` and `columns` are required: a search without either has
  /// nothing to look for or nowhere to look.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakSearch fromJson(Map<String, Object?> json) {
    final columnKeys = switch (requireJsonKey(json, 'columns', 'BeakSearch')) {
      final List<Object?> values => [
        for (final value in values)
          if (value is String)
            value
          else
            throw BeakConfigurationException(
              'BeakSearch JSON key "columns" must contain only strings, '
              'got $value.',
            ),
      ],
      final Object? other => throw BeakConfigurationException(
        'BeakSearch JSON key "columns" must be a list, got $other.',
      ),
    };
    return BeakSearch(
      requireJsonString(json, 'term', 'BeakSearch'),
      columnKeys,
    );
  }

  /// The text being searched for.
  final String term;

  /// Keys of the columns the term is matched against.
  final List<String> columnKeys;

  /// This search as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'term': term,
    'columns': [...columnKeys],
  };

  @override
  bool operator ==(Object other) =>
      other is BeakSearch &&
      other.term == term &&
      listEquals(other.columnKeys, columnKeys);

  @override
  int get hashCode => Object.hash(term, Object.hashAll(columnKeys));

  @override
  String toString() => 'BeakSearch($term in $columnKeys)';
}
