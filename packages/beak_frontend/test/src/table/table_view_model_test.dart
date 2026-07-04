import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late TableViewModel viewModel;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
        },
      },
    );
    viewModel = TableViewModel(const NoteModel(), dataSource);
  });

  tearDown(() => viewModel.dispose());

  test('refresh loads the page and clears errors', () async {
    await viewModel.refresh();
    expect(viewModel.page.value?.total, 1);
    expect(viewModel.loading.value, isFalse);
    expect(viewModel.error.value, isNull);
  });

  test('sortBy replaces the ordering and resets to the first page', () async {
    viewModel.goToPage(3);
    viewModel.sortBy(const NoteModel().columns[1], descending: true);
    await pumpEventQueue();

    final spec = dataSource.queryCalls.last;
    expect(spec.sorts, [const BeakSort('title', descending: true)]);
    expect(spec.pagination.page, 1, reason: 'sorting restarts pagination');

    viewModel.sortBy(const NoteModel().columns.first);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.sorts, [
      const BeakSort('id'),
    ], reason: 'sorts replace, never stack');
  });

  test('setSearch searches the searchable columns only', () async {
    viewModel.setSearch('laser');
    await pumpEventQueue();

    final spec = dataSource.queryCalls.last;
    expect(spec.search, const BeakSearch('laser', ['title']));

    viewModel.setSearch('   ');
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.search, isNull);
  });

  test('setFilter replaces and clears the filter tree', () async {
    const filter = BeakFieldFilter.forKey(
      'title',
      BeakOperator.eq,
      BeakStringValue('One'),
    );
    viewModel.setFilter(filter);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.filter, filter);

    viewModel.setFilter(null);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.filter, isNull);
  });

  test('setFilter AND-merges with the base filter, and clearing reverts '
      'to it', () async {
    const base = BeakFieldFilter.forKey(
      'id',
      BeakOperator.eq,
      BeakStringValue('n1'),
    );
    final scoped = TableViewModel(
      const NoteModel(),
      dataSource,
      baseFilter: base,
    );
    addTearDown(scoped.dispose);

    const columnFilter = BeakFieldFilter.forKey(
      'title',
      BeakOperator.contains,
      BeakStringValue('One'),
    );
    scoped.setFilter(columnFilter);
    await pumpEventQueue();
    expect(
      dataSource.queryCalls.last.filter,
      const BeakAndFilter([base, columnFilter]),
      reason: 'the base filter survives an in-table column filter',
    );

    scoped.setFilter(null);
    await pumpEventQueue();
    expect(
      dataSource.queryCalls.last.filter,
      base,
      reason: 'clearing the column filter reverts to the base, not null',
    );
  });

  test(
    'a superseded out-of-order response never overwrites the latest',
    () async {
      final ordered = _GatedSource();
      final raced = TableViewModel(const NoteModel(), ordered);
      addTearDown(raced.dispose);

      final first = raced.refresh();
      final second = raced.refresh();

      // Resolve the NEWER request first, then the stale older one.
      ordered.release(1, total: 222);
      ordered.release(0, total: 111);
      await Future.wait([first, second]);

      expect(
        raced.page.value?.total,
        222,
        reason: 'the superseded response 111 must not clobber the latest 222',
      );
      expect(raced.loading.value, isFalse);
    },
  );

  test('goToPage and setPageSize drive pagination', () async {
    viewModel.goToPage(4);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.pagination.page, 4);

    viewModel.setPageSize(50);
    await pumpEventQueue();
    expect(
      dataSource.queryCalls.last.pagination,
      const BeakPagination(perPage: 50),
    );
  });

  test('failures surface as typed error state', () async {
    final failingViewModel = TableViewModel(
      const NoteModel(),
      _FailingSource(),
    );
    addTearDown(failingViewModel.dispose);

    await failingViewModel.refresh();

    expect(failingViewModel.error.value, isA<BeakStorageException>());
    expect(failingViewModel.loading.value, isFalse);
    expect(failingViewModel.page.value, isNull);
  });
}

/// A data source whose queries always fail.
final class _FailingSource extends FakeDataSource {
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    throw const BeakStorageException('backend unreachable');
  }
}

/// A data source whose queries block until [release]d, so tests can resolve
/// concurrent requests out of order.
final class _GatedSource extends FakeDataSource {
  final List<Completer<int>> _gates = [];

  /// Completes the [callIndex]-th pending query with a page of [total].
  void release(int callIndex, {required int total}) =>
      _gates[callIndex].complete(total);

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    final gate = Completer<int>();
    _gates.add(gate);
    final int total = await gate.future;
    return BeakPage(items: const [], total: total, page: 1, perPage: 20);
  }
}
