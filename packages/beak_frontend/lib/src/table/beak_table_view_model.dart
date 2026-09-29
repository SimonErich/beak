import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../state/beak_view_model.dart';
import '../query/beak_query_controller.dart';
import '../data/beak_relation_loads.dart';

/// Owns a list view's query spec and page state: every sort/filter/search/
/// pagination intent rewrites the [BeakQuerySpec] and refetches through the
/// repository (the catch boundary) — the table widget just renders signals.
/// Repeating an unchanged table intent does not refetch; [refresh] always does.
final class BeakTableViewModel extends BeakViewModel {
  /// Creates the view model for [model] over [dataSource], starting from
  /// [initial] (default: an unfiltered first page).
  ///
  /// [baseFilter] is a persistent predicate outside the table's control
  /// (the filter bar's) that every in-table filter change AND-merges with
  /// instead of replacing.
  BeakTableViewModel(
    this.model,
    BeakDataSource dataSource, {
    BeakQuerySpec? initial,
    BeakFilter? baseFilter,
    this.queryController,
    this.queryFields = const [],
  }) : _repository = BeakResourceRepository(dataSource),
       _baseFilter = baseFilter {
    _spec = ownedSignal(
      _scoped(
        beakWithFieldLoads(
          initial ?? BeakQuerySpec(table: model.table),
          queryFields,
        ),
      ),
    );
    _page = ownedSignal<BeakPage<BeakRecord>?>(null);
    _loading = ownedSignal(false);
    _error = ownedSignal<BeakException?>(null);
    if (queryController case final BeakQueryController controller) {
      _queryCleanup = effect(() {
        final next = _scoped(beakWithFieldLoads(controller.query, queryFields));
        if (_spec.peek() != next) {
          _spec.value = next;
          unawaited(refresh());
        }
      });
    }
    if (dataSource case final BeakMutationSource source) {
      _changes = source.changes.listen((change) {
        if (change.affects(model.table) && !isDisposed) unawaited(refresh());
      });
    }
  }

  /// The model this table lists.
  final BeakModel model;

  final BeakResourceRepository _repository;
  final BeakFilter? _baseFilter;

  /// Shared list query; absent for the traditional standalone table.
  final BeakQueryController? queryController;

  /// Additional eager dependencies of composite cells.
  final List<BeakFieldRef<Object>> queryFields;
  void Function()? _queryCleanup;

  int _latestRequestId = 0;
  StreamSubscription<BeakDataChange>? _changes;

  @override
  void dispose() {
    _queryCleanup?.call();
    unawaited(_changes?.cancel());
    super.dispose();
  }

  late final Signal<BeakQuerySpec> _spec;
  late final Signal<BeakPage<BeakRecord>?> _page;
  late final Signal<bool> _loading;
  late final Signal<BeakException?> _error;

  /// The spec the next fetch runs.
  ReadonlySignal<BeakQuerySpec> get spec => _spec;

  /// The last fetched page, or `null` before the first load.
  ReadonlySignal<BeakPage<BeakRecord>?> get page => _page;

  /// Whether a fetch is in flight.
  ReadonlySignal<bool> get loading => _loading;

  /// The last fetch failure, cleared by the next fetch.
  ReadonlySignal<BeakException?> get error => _error;

  /// Replaces the ordering with [column] (list views sort by one column)
  /// and refetches from the first page.
  void sortBy(BeakColumn column, {bool descending = false}) {
    if (queryController case final BeakQueryController controller) {
      controller.sortBy(column, descending: descending);
      return;
    }
    _mutateSpec(
      (spec) => _rebuild(
        spec,
        sorts: [BeakSort(column.key, descending: descending)],
        firstPage: true,
      ),
    );
  }

  /// Replaces the table's own filter tree ([filter] `null` clears it back
  /// to the base filter), AND-merging a provided [filter] with the base
  /// filter, and refetches from the first page.
  void setFilter(BeakFilter? filter) {
    if (queryController case final BeakQueryController controller) {
      controller.applyFilters(
        {...controller.state.value.filters}
          ..remove('_table')
          ..addAll({'_table': ?filter}),
      );
      return;
    }
    _mutateSpec(
      (spec) => _rebuild(
        spec,
        filter: filter,
        clearFilter: filter == null,
        firstPage: true,
      ),
    );
  }

  /// Searches [term] across the model's searchable columns (a blank term
  /// clears the search) and refetches from the first page.
  void setSearch(String term) {
    if (queryController case final BeakQueryController controller) {
      controller.setSearch(term);
      return;
    }
    final searchableColumns = [
      for (final column in model.columns)
        if (column.searchable) column,
    ];
    final BeakSearch? search = term.trim().isEmpty || searchableColumns.isEmpty
        ? null
        : BeakSearch(term, [
            for (final column in searchableColumns) column.key,
          ]);
    _mutateSpec(
      (spec) => _rebuild(
        spec,
        search: search,
        clearSearch: search == null,
        firstPage: true,
      ),
    );
  }

  /// Jumps to 1-based [pageNumber] and refetches.
  void goToPage(int pageNumber) {
    if (queryController case final BeakQueryController controller) {
      controller.goToPage(pageNumber);
      return;
    }
    _mutateSpec((spec) => spec.paginate(page: pageNumber));
  }

  /// Changes the page size (resetting to the first page) and refetches.
  void setPageSize(int perPage) {
    if (queryController case final BeakQueryController controller) {
      controller.setPageSize(perPage);
      return;
    }
    _mutateSpec((spec) => spec.paginate(page: 1, perPage: perPage));
  }

  /// Removes the record with [id] from the current page (an optimistic
  /// apply), returning the removed record and its index for a revert —
  /// or `null` when the page has no such record.
  ({BeakRecord record, int index})? removeLocally(Object id) {
    final current = _page.value;
    if (current == null) {
      return null;
    }
    final int index = _indexOf(current, id);
    if (index < 0) {
      return null;
    }
    final record = current.items[index];
    _page.value = BeakPage(
      items: [...current.items]..removeAt(index),
      total: current.total - 1,
      page: current.page,
      perPage: current.perPage,
    );
    return (record: record, index: index);
  }

  /// Re-inserts a locally removed [record] at [index] (an optimistic
  /// rollback).
  void insertLocally(BeakRecord record, int index) {
    final current = _page.value;
    if (current == null) {
      return;
    }
    _page.value = BeakPage(
      items: [...current.items]..insert(index, record),
      total: current.total + 1,
      page: current.page,
      perPage: current.perPage,
    );
  }

  /// Replaces one value of the record with [id] locally (optimistic inline
  /// edit), returning the previous record for a revert — or `null` when the
  /// page has no such record.
  BeakRecord? replaceRecordLocally(Object id, BeakRecord updated) {
    final current = _page.value;
    if (current == null) {
      return null;
    }
    final int index = _indexOf(current, id);
    if (index < 0) {
      return null;
    }
    final previous = current.items[index];
    _page.value = BeakPage(
      items: [...current.items]
        ..removeAt(index)
        ..insert(index, updated),
      total: current.total,
      page: current.page,
      perPage: current.perPage,
    );
    return previous;
  }

  int _indexOf(BeakPage<BeakRecord> page, Object id) {
    final String primaryKeyColumn = model.primaryKey.key;
    for (final (index, record) in page.items.indexed) {
      if (record[primaryKeyColumn]?.raw == id) {
        return index;
      }
    }
    return -1;
  }

  /// Refetches the current spec.
  ///
  /// Concurrent calls resolve latest-wins: a response belonging to a
  /// superseded request never overwrites newer page/error/loading state.
  // --8<-- [start:refresh]
  Future<void> refresh() async {
    if (isDisposed) return;
    final int requestId = ++_latestRequestId;
    _loading.value = true;
    _error.value = null;
    final result = await _repository.query(_spec.value);
    if (isDisposed || requestId != _latestRequestId) {
      return;
    }
    switch (result) {
      case BeakOk(:final value):
        _page.value = value;
      case BeakErr(:final error):
        _error.value = error;
    }
    _loading.value = false;
  }
  // --8<-- [end:refresh]

  void _mutateSpec(BeakQuerySpec Function(BeakQuerySpec spec) change) {
    final next = change(_spec.value);
    if (next == _spec.value) return;
    _spec.value = next;
    unawaited(refresh());
  }

  // Apply permanent scope before the first fetch and whenever shared query
  // state changes. Subsequent standalone sort/page/search mutations preserve
  // this spec; refresh therefore never fetches unscoped rows or totals.
  BeakQuerySpec _scoped(BeakQuerySpec spec) => switch (_baseFilter) {
    null => spec,
    final BeakFilter base when spec.filter == base => spec,
    final BeakFilter base => spec.withFilter(base),
  };

  /// Rebuilds a spec with replaced parts — the core spec builders only
  /// append, while table interactions replace (a provided [filter] still
  /// AND-merges with the persistent base filter).
  BeakQuerySpec _rebuild(
    BeakQuerySpec spec, {
    List<BeakSort>? sorts,
    BeakFilter? filter,
    bool clearFilter = false,
    BeakSearch? search,
    bool clearSearch = false,
    bool firstPage = false,
  }) => BeakQuerySpec(
    table: spec.table,
    filter: clearFilter
        ? _baseFilter
        : (filter == null ? spec.filter : _withBase(filter)),
    sorts: sorts ?? spec.sorts,
    search: clearSearch ? null : (search ?? spec.search),
    relationLoads: spec.relationLoads,
    pagination: firstPage
        ? BeakPagination(perPage: spec.pagination.perPage)
        : spec.pagination,
    withTrashed: spec.withTrashed,
  );

  /// AND-merges the table's own [filter] with the persistent base filter
  /// so the filter bar and the column filters never clobber each other.
  BeakFilter _withBase(BeakFilter filter) => switch (_baseFilter) {
    null => filter,
    final BeakFilter base => BeakAndFilter([base, filter]),
  };
}
