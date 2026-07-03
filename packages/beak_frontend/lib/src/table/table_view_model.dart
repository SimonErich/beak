import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../data/beak_resource_repository.dart';
import '../state/beak_view_model.dart';

/// Owns a list view's query spec and page state: every sort/filter/search/
/// pagination intent rewrites the [BeakQuerySpec] and refetches through the
/// repository (the catch boundary) — the table widget just renders signals.
final class TableViewModel extends BeakViewModel {
  /// Creates the view model for [model] over [dataSource], starting from
  /// [initial] (default: an unfiltered first page).
  TableViewModel(
    this.model,
    BeakDataSource dataSource, {
    BeakQuerySpec? initial,
  }) : _repository = BeakResourceRepository(dataSource) {
    _spec = ownedSignal(initial ?? BeakQuerySpec(table: model.table));
    _page = ownedSignal<BeakPage<BeakRecord>?>(null);
    _loading = ownedSignal(false);
    _error = ownedSignal<BeakException?>(null);
  }

  /// The model this table lists.
  final BeakModel model;

  final BeakResourceRepository _repository;

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
    _mutateSpec(
      (spec) => _rebuild(
        spec,
        sorts: [BeakSort(column.key, descending: descending)],
        firstPage: true,
      ),
    );
  }

  /// Replaces the filter tree ([filter] `null` clears it) and refetches
  /// from the first page.
  void setFilter(BeakFilter? filter) {
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
    _mutateSpec((spec) => spec.paginate(page: pageNumber));
  }

  /// Changes the page size (resetting to the first page) and refetches.
  void setPageSize(int perPage) {
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
  Future<void> refresh() async {
    _loading.value = true;
    _error.value = null;
    final result = await _repository.query(_spec.value);
    switch (result) {
      case BeakOk(:final value):
        _page.value = value;
      case BeakErr(:final error):
        _error.value = error;
    }
    _loading.value = false;
  }

  void _mutateSpec(BeakQuerySpec Function(BeakQuerySpec spec) change) {
    _spec.value = change(_spec.value);
    unawaited(refresh());
  }

  /// Rebuilds a spec with replaced parts — the core spec builders only
  /// append, while table interactions replace.
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
    filter: clearFilter ? null : (filter ?? spec.filter),
    sorts: sorts ?? spec.sorts,
    search: clearSearch ? null : (search ?? spec.search),
    relationLoads: spec.relationLoads,
    pagination: firstPage
        ? BeakPagination(perPage: spec.pagination.perPage)
        : spec.pagination,
    withTrashed: spec.withTrashed,
  );
}
